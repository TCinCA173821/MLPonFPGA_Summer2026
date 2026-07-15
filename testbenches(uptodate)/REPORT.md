# Testbench & Synthesis Report

Fresh, self-checking testbenches were written for **every module** in `source/`, and
each was run through **Verilator 5.020** (compile + simulate) and **Yosys 0.33**
(synthesis). The previously-existing testbenches were outdated — they instantiated
modules/ports that no longer exist (e.g. `tb_mac` drove a `MACblock` with ports
`input1_signed`, `MACout_REG`, `data_valid` that the current `MAC` module does not
have) — so they were replaced.

Run everything with:

```bash
./testbench/run_verification.sh
```

Artifacts land in `build/ver/<module>/` (sim logs + waveforms) and
`build/synth/<module>.log` (synthesis logs). Each testbench also emits a
`<module>.vcd` waveform when simulated.

## Module inventory (20 modules → 20 testbenches)

| Source file | Module | Testbench |
|---|---|---|
| `mac/MACmodule.sv` | `mixedsign4bitmult` | `testbench/mixedsign4bitmult/tb_mixedsign4bitmult.sv` |
| `mac/MACmodule.sv` | `addersigned16bit` | `testbench/addersigned16bit/tb_addersigned16bit.sv` |
| `mac/MACmodule.sv` | `accreg` | `testbench/accreg/tb_accreg.sv` |
| `mac/MACmodule.sv` | `relu` | `testbench/relu/tb_relu.sv` |
| `mac/MACmodule.sv` | `MAC` | `testbench/MAC/tb_MAC.sv` |
| `spi_image_system/SPImodule.sv` | `SPI_shiftreg` | `testbench/SPI_shiftreg/tb_SPI_shiftreg.sv` |
| `spi_image_system/SPImodule.sv` | `SPI_FSM` | `testbench/SPI_FSM/tb_SPI_FSM.sv` |
| `spi_image_system/SPImodule.sv` | `dualffsync` | `testbench/dualffsync/tb_dualffsync.sv` |
| `spi_image_system/SPImodule.sv` | `SPI_mod` | `testbench/SPI_mod/tb_SPI_mod.sv` |
| `hidden_layer_buffer/hidden_layer_buffer.sv` | `hidden_layer_buffer` | `testbench/hidden_layer_buffer/tb_hidden_layer_buffer.sv` |
| `output_layer_buffer/output_layer_buffer.sv` | `output_layer_buffer` | `testbench/output_layer_buffer/tb_output_layer_buffer.sv` |
| `argmax/argmax.sv` | `argmax` | `testbench/argmax/tb_argmax.sv` |
| `seven_seg/seven_seg.sv` | `ssdec` | `testbench/ssdec/tb_ssdec.sv` |
| `Maincontroller/mainctrlfsm.sv` | `main_ctrlfsm` | `testbench/main_ctrlfsm/tb_main_ctrlfsm.sv` |
| `Maincontroller/layer_controller.sv` | `layer_controller` | `testbench/layer_controller/tb_layer_controller.sv` |
| `Maincontroller/MAC_controller.sv` | `MAC_controller` | `testbench/MAC_controller/tb_MAC_controller.sv` |
| `Maincontroller/argmax_controller.sv` | `argmax_controller` | `testbench/argmax_controller/tb_argmax_controller.sv` |
| `Maincontroller/inputcontroller.sv` | `input_controller` | `testbench/input_controller/tb_input_controller.sv` |
| `Maincontroller/controllertop.sv` | `controllertop` | `testbench/controllertop/tb_controllertop.sv` |
| `top.sv` | `top` | `testbench/top/tb_top.sv` |

## Results

| Module | Verilator sim | Yosys synth | Cells |
|---|---|---|---|
| mixedsign4bitmult | ✅ PASS | ⚠️ frontend-limited | – |
| addersigned16bit | ✅ PASS | ⚠️ frontend-limited | – |
| accreg | ✅ PASS | ⚠️ frontend-limited | – |
| relu | ✅ PASS | ⚠️ frontend-limited | – |
| MAC | ✅ PASS | ⚠️ frontend-limited | – |
| SPI_shiftreg | ✅ PASS | ✅ PASS | 32 |
| SPI_FSM | ✅ PASS | ✅ PASS | 13 |
| dualffsync | ✅ PASS | ✅ PASS | 2 |
| SPI_mod | ✅ PASS | ✅ PASS | 47 |
| hidden_layer_buffer | ✅ PASS | ⚠️ frontend-limited | – |
| output_layer_buffer | ✅ PASS | ⚠️ frontend-limited | – |
| argmax | ✅ PASS | ✅ PASS | 99 |
| ssdec | ✅ PASS | ✅ PASS | 26 |
| main_ctrlfsm | ✅ PASS | ✅ PASS | 32 |
| layer_controller | ✅ PASS | ✅ PASS | 28 |
| MAC_controller | ✅ PASS | ✅ PASS | 105 |
| argmax_controller | ✅ PASS | ✅ PASS | 26 |
| input_controller | ✅ PASS | ⚠️ frontend-limited | – |
| controllertop | ✅ PASS | ⚠️ frontend-limited | – |
| top | ❌ does not elaborate | ❌ | – |

**Verilator: 19/20 pass** (every testbench's self-checks pass). The
`controllertop` integration test drives the whole pipeline and reaches a **full
inference completion** — `Done` asserts after ~7350 cycles and 1044 emulated SPI
packet requests.

**Yosys: 11/20 synthesize** to a generic cell netlist. The 9 "frontend-limited"
modules are *not* logic errors — they simulate correctly in Verilator. They fail
only because **Yosys 0.33's built-in Verilog frontend has incomplete SystemVerilog
support**:

- **Multi-dimensional packed array ports** — `input logic [3:0][3:0] in`
  (`hidden_layer_buffer`, `output_layer_buffer`): *"syntax error, unexpected '['"*.
- **Unpacked array ports** — `logic signed [7:0] MAC_in [0:3]`
  (`input_controller`, `controllertop`): *"unexpected '[', expecting ',' or '=' or ')'"*.
- **Signedness assertion bug** in `genrtlil.cc` triggered by the `$signed(...)`
  port hookups in the MAC hierarchy (`mixedsign4bitmult`, `addersigned16bit`,
  `accreg`, `relu`, `MAC`).

To synthesize these in Yosys you would use a fuller SV frontend (e.g. the
`slang`/Verific plugin) or flatten the array ports; the RTL itself is sound.

## Source fixes required to compile/synthesize

These were genuine, compile-blocking bugs (unrelated to the testbenches). Each fix
is semantically faithful to the surrounding RTL and the block diagram:

1. **`spi_image_system/SPImodule.sv`** (`SPI_shiftreg`):
   - missing comma after `input logic [7:0] mosi`
   - `alawys_ff` → `always_ff`
   - missing semicolon after `assign SPI_reg = intreg`
2. **`Maincontroller/inputcontroller.sv`** (`input_controller`):
   - variable part-selects `SPI_d[31-8*j:28-8*j]` → indexed part-selects
     `SPI_d[31-8*j -: 4]` (Verilog requires constant `[a:b]` bounds; both slices
     are 4 bits, so this is equivalent).
   - `MAC_in <= '0` → `MAC_in <= '{default:'0}` (assignment pattern for the
     unpacked `MAC_in [0:3]` array).

## Known-broken: `top.sv`

`source/top.sv` is a work-in-progress and does not elaborate in either tool. Issues
observed (design-level, left untouched — they need design decisions, not mechanical
fixes):

- `WIDTH` used in the generate loop is never declared (a parameter/localparam).
- The generate block label is missing: `for (...) begin :` needs a name.
- No system clock net exists (submodules need `clk`; top only has `hz100`, `reset`).
- Port-name mismatch: `output_layer_buffer` port is `out_data`, instantiated as `.outdata(...)`.
- Packed-vs-unpacked array mismatches across module boundaries (e.g. `MAC_out [0:3]`
  vs `in [3:0][15:0]`; `HLBrdata` unpacked vs `hidden_layer_buffer.out` packed).

`tb_top.sv` is provided and documents the intended top-level stimulus (hz100 clock,
reset, and the SPI push-button mapping) for once the above are resolved.
