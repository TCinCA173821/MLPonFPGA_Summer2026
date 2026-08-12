# MLPonFPGA

A handwritten-digit classifier that runs entirely as digital logic on an FPGA.

A small multilayer perceptron is trained in PyTorch, quantized down to **4-bit
weights and 4-bit pixels**, and then evaluated by a SystemVerilog datapath —
four multiply-accumulate lanes, two layer buffers, an argmax unit, and a
seven-segment decoder. A Raspberry Pi Pico sits between the host PC and the
FPGA: it receives an image over USB and streams the image and the trained
weights to the FPGA one 4-byte packet at a time.

There is no soft CPU and no memory controller in the design. Weights are never
stored on the FPGA — every weight arrives on the bus at the exact moment the
MAC lanes need it.

---

## Table of contents

- [How it works](#how-it-works)
- [The network](#the-network)
- [Repository layout](#repository-layout)
- [The packet protocol](#the-packet-protocol)
- [Getting started](#getting-started)
  - [1. Train and quantize the model](#1-train-and-quantize-the-model)
  - [2. Build and flash the Pico](#2-build-and-flash-the-pico)
  - [3. Synthesize the FPGA design](#3-synthesize-the-fpga-design)
  - [4. Run an inference](#4-run-an-inference)
- [Simulation and testbenches](#simulation-and-testbenches)
- [Collecting your own dataset](#collecting-your-own-dataset)
- [Contributing](#contributing)

---

## How it works

```
  ┌──────────────┐   USB CDC    ┌──────────────┐   8-bit bus + SPI-like   ┌──────────────┐
  │   Host PC    │  "IMG1" +    │  Pi Pico     │   clocking (D[7:0],      │    FPGA      │
  │              │  196 pixels  │              │   SCLK, CS, START,       │              │
  │ send_image.py├─────────────►│  firmware    ├─  NXTPCKT) ─────────────►│  MLP  logic  │
  └──────────────┘              │              │                          │              │
                                │ holds weights│◄── requests next packet ─┤  7-seg out   │
                                └──────────────┘                          └──────────────┘
```

1. **Host → Pico.** `send_image.py` loads any image file, converts it to
   14×14 grayscale, quantizes each pixel to 4 bits, and sends `"IMG1"` followed
   by 196 bytes over USB serial.
2. **Pico builds the packet stream.** With the image in hand, the firmware
   assembles all **839 packets** for one inference into a single array in RAM —
   each packet pairing a trained weight with the pixel or hidden activation it
   multiplies.
3. **Pico → FPGA, on demand.** The Pico raises `START`. From then on the FPGA
   pulls: every time it is ready it raises `NXTPCKT`, and the Pico shifts out
   the next 4-byte packet using PIO + DMA. The FPGA samples `D[7:0]` on each
   rising `SCLK` edge into a 32-bit shift register.
4. **FPGA computes.** A controller FSM walks `IDLE → HIDDENLAYER →
   OUTPUTLAYER → ARGMAX → PULSEDONE`, feeding the four MAC lanes, latching
   biases, applying ReLU, and buffering results between layers.
5. **Result.** Argmax picks the winning class and the digit appears on the
   seven-segment display, with `Done` asserted on an LED.

The whole design is **four MACs wide**, so both layers are processed in groups
of four neurons: 16 hidden neurons = 4 groups, 10 output neurons = 3 groups
(the last group leaves two lanes idle).

---

## The network

| Property | Value |
| --- | --- |
| Topology | 196 → 16 → 10, fully connected |
| Activation | ReLU (hidden layer only) |
| Input | 14×14 grayscale, **unsigned 4-bit** (0–15) |
| Weights | **signed 4-bit** (−8 … 7) |
| Biases | **signed 8-bit** (−128 … 127) |
| Accumulator | signed 16-bit |
| Output | argmax over 10 signed 16-bit scores |

The hidden layer's ReLU also **truncates back to 4 bits** so the result can be
fed straight into the next layer's 4-bit multipliers: negatives clamp to 0,
anything above 15 saturates to 15.

Training is a two-stage process — a float model first (`train.py`), then
quantization-aware fine-tuning (`qatuning.py`) so the network learns to live
with 4-bit weights before they are actually rounded (`quantize.py`).

---

## Repository layout

```
source/                    SystemVerilog RTL — the design itself
  top.sv                     board top level: wires everything to pins
  mac/MACmodule.sv           4-bit signed×unsigned multiplier, 16-bit adder,
                             accumulator register, ReLU+truncate, MAC wrapper
  spi_image_system/          32-bit shift register, CS synchronizer, SPI FSM
  Maincontroller/            controllertop + main FSM, layer / MAC / input /
                             argmax sub-controllers
  hidden_layer_buffer/       4×16-bit shift buffer for hidden activations
  output_layer_buffer/       12×16-bit buffer for output-layer scores
  argmax/                    streaming max-with-index
  seven_seg/                 hex → seven-segment decoder

testbench/                 Current module testbenches (one per RTL module)
testbenches(archive)/      Older testbench generation, kept for reference

pico_to_fpga/              Raspberry Pi Pico firmware (C, pico-sdk)
  source/main.c              builds the 839-packet array, runs the handshake
  source/form_packet.c       packs weight+pixel into each 4-byte packet
  source/dma_packet_stream.c PIO + DMA packet transmitter
  source/sendpckt.pio        PIO program that drives D[7:0]/SCLK/CS
  source/handshake.c         START / NXTPCKT GPIO handshake
  source/usb_image.c         receives "IMG1" + 196 pixels over USB CDC
  source/weights.c/.h        exported model data, in packet order
  source/hardware_config.h   all pin numbers and bus timing in one place
  host/send_image.py         host-side image sender
  firmware/pico_to_fpga.uf2  prebuilt firmware

vision_model_ver2.0/       PyTorch model and quantization pipeline
  train.py                   trains the float MLP
  qatuning.py                quantization-aware fine-tuning
  quantize.py                converts to int4 weights / int8 biases
  integer_inference.py       pure-integer forward pass (matches the hardware)
  predict.py                 classify a single image
  custom_accuracy.py         accuracy over your own collected digits
  error_distribution.py      confusion matrix
  preprocess.py              MNIST loading, resize to 14×14, quantize to 4 bits
  preprocessing224.py        downsample a 224×224 capture to the input format
  models/export_weights.py   emits weights.c in packet-transmission order

dataset_collector/         Offline web app for collecting handwritten digits
```

---

## The packet protocol

Every transfer is exactly **4 bytes**, and the FPGA requests each one. There
are three packet types:

| Type | Byte layout | Meaning |
| --- | --- | --- |
| `BIAS` | 4 × signed int8 | Preloads the four MAC accumulators for the next group of neurons |
| `HIDDEN` | `WWWWPPPP` × 4 | One pixel broadcast to four hidden neurons, each with its own weight |
| `OUTPUT` | `WWWWPPPP` × 4 | One hidden activation broadcast to four output neurons |

Each byte carries a **signed 4-bit weight in the upper nibble** and the
**unsigned 4-bit operand in the lower nibble**, so one packet feeds all four
MAC lanes for one cycle of accumulation.

One inference is:

```
4 hidden groups × (1 bias packet + 196 pixel packets)  = 788
3 output groups × (1 bias packet +  16 hidden packets) =  51
                                                  total = 839 packets
```

Bias values are shared across the whole run: there are 26 biases (16 hidden +
10 output) which fill 7 bias packets, one per group, with the last packet's
spare bytes zeroed.

Pin assignments and bus timing live in
[`pico_to_fpga/source/hardware_config.h`](pico_to_fpga/source/hardware_config.h).
All signals are active-high and `SCLK` idles low. The default setup/hold delays
are deliberately slow (10 ms) for probing with a logic analyzer — tighten them
once the link is known good.

---

## Getting started

### 1. Train and quantize the model

```bash
cd vision_model_ver2.0
pip install torch torchvision numpy pillow pyserial

python train.py          # float model      -> models/best_model.pth
python qatuning.py       # QAT fine-tune    -> models/best_qat_model.pth
python quantize.py       # int4 conversion  -> models/quantized_model.pth

python integer_inference.py   # accuracy using integer-only arithmetic
python error_distribution.py  # per-digit confusion matrix
```

Then export the weights in the order the packet stream expects:

```bash
python models/export_weights.py    # -> models/weights.c
cp models/weights.c ../pico_to_fpga/source/weights.c
```

`integer_inference.py` is the reference implementation of what the RTL should
compute. If hardware and software disagree, that file is the arbiter.

### 2. Build and flash the Pico

Use the prebuilt firmware, or build it yourself with the pico-sdk:

```bash
cd pico_to_fpga
mkdir build && cd build
cmake .. && make -j
```

Hold BOOTSEL while plugging in the Pico and copy `pico_to_fpga.uf2` (or
`firmware/pico_to_fpga.uf2`) to the mounted RPI-RP2 drive.

### 3. Synthesize the FPGA design

Add everything under `source/` to your project and set `top` as the top-level
module. `top.sv` maps the interface onto the dev board's pushbuttons and LEDs:

| Signal | Pin |
| --- | --- |
| `start` | `pb[9]` |
| `cs` | `pb[10]` |
| `sclk` | `pb[11]` |
| `mosi[7:0]` | `pb[19:12]` |
| `Done` | `left[0]` |
| `NXTPCKT` to Pico | `left[1]` |
| predicted digit | `left[5:2]` and `ss0` |
| clock | `hz100` |

Wire the Pico's `D[7:0]`, `SCLK`, `CS`, and `START` to those pushbutton inputs
and the FPGA's `NXTPCKT` output back to the Pico, and share a ground.

> `source/top(witheverything).sv` is an alternate top level kept for
> bring-up/debug; the synthesized design is `source/top.sv`.

### 4. Run an inference

```bash
cd pico_to_fpga/host
python send_image.py path/to/digit.png            # add --invert for dark-on-light
```

The Pico quantizes nothing on its own — it receives 196 pre-quantized pixels,
builds the packet array, pulses `START`, and streams. Within a few hundred
packet exchanges the predicted digit appears on the seven-segment display and
`Done` goes high.

---

## Simulation and testbenches

Each RTL module has a matching testbench in `testbench/`, named
`<module>_tb.sv`. Any standard simulator works — with Icarus Verilog:

```bash
iverilog -g2012 -o build/mac_tb source/mac/MACmodule.sv testbench/MACModule_tb.sv
vvp build/mac_tb
gtkwave dump.vcd     # if the testbench writes one
```

`testbench/top_tb.sv` and `testbench/tb_spi_packet_chain.sv` exercise the full
datapath and the packet-reception chain respectively, which is the fastest way
to check a change end to end.

An older Verilator + Yosys sweep script lives in
`testbench/testbench_archive/tb_output_layer_buffer/run_verification.sh`. It
predates the current file layout and its paths need updating before it runs.

---

## Collecting your own dataset

`dataset_collector/index.html` is a single-file, offline web app for gathering
handwritten digits on a tablet. It exports 28×28 8-bit grayscale PNGs in true
MNIST normalization (20×20 aspect-preserved, centered by center of mass), which
drop straight into `preprocess.py`. See
[`dataset_collector/README.md`](dataset_collector/README.md) for details.

Score the model against what you collect with
`vision_model_ver2.0/custom_accuracy.py`.

---

## Contributing

Collaborators: feel free to add folders or reorganize anything that makes the
project easier to navigate. A few conventions worth keeping:

- One RTL module family per folder under `source/`, with a matching
  `<module>_tb.sv` in `testbench/`.
- Pin numbers and timing go in `hardware_config.h`, not scattered through the
  protocol code.
- If you change the packet ordering, change it in three places together:
  `export_weights.py`, `form_packet.c`, and the input controller RTL.
