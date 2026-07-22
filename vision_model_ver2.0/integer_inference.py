from pathlib import Path

import torch
from torch.utils.data import DataLoader

from preprocess import load_mnist


# --------------------------------------------------
# File paths
# --------------------------------------------------

BASE_DIR = Path(__file__).resolve().parent
MODEL_DIR = BASE_DIR / "models"

QUANTIZED_MODEL_PATH = MODEL_DIR / "quantized_model.pth"


# --------------------------------------------------
# Network and hardware specifications
# --------------------------------------------------

BATCH_SIZE = 256

INPUT_SIZE = 196
HIDDEN_SIZE = 16
OUTPUT_SIZE = 10

INPUT_MIN = 0
INPUT_MAX = 15

WEIGHT_MIN = -8
WEIGHT_MAX = 7

BIAS_MIN = -128
BIAS_MAX = 127

ACCUMULATOR_MIN = -32768
ACCUMULATOR_MAX = 32767

RELU_MIN = 0
RELU_MAX = 15


def wrap_to_int16(values: torch.Tensor) -> torch.Tensor:
    """
    Reproduce signed 16-bit two's-complement overflow.

    SystemVerilog's 16-bit accumulator discards bits above bit 15.
    This function reproduces that behavior.
    """
    values = values.to(torch.int64)

    wrapped = torch.remainder(
        values - ACCUMULATOR_MIN,
        2 ** 16
    ) + ACCUMULATOR_MIN

    return wrapped.to(torch.int32)


def validate_quantized_model(model_state: dict) -> None:
    """Verify that all model parameters match the FPGA bit limits."""
    required_keys = {
        "fc1.weight",
        "fc1.bias",
        "fc2.weight",
        "fc2.bias",
    }

    missing_keys = required_keys - set(model_state.keys())

    if missing_keys:
        raise KeyError(
            "Quantized model is missing these parameters: "
            f"{sorted(missing_keys)}"
        )

    fc1_weight = model_state["fc1.weight"]
    fc1_bias = model_state["fc1.bias"]
    fc2_weight = model_state["fc2.weight"]
    fc2_bias = model_state["fc2.bias"]

    if tuple(fc1_weight.shape) != (HIDDEN_SIZE, INPUT_SIZE):
        raise ValueError(
            "fc1.weight must have shape "
            f"({HIDDEN_SIZE}, {INPUT_SIZE}), "
            f"but received {tuple(fc1_weight.shape)}."
        )

    if tuple(fc1_bias.shape) != (HIDDEN_SIZE,):
        raise ValueError(
            "fc1.bias must have shape "
            f"({HIDDEN_SIZE},), "
            f"but received {tuple(fc1_bias.shape)}."
        )

    if tuple(fc2_weight.shape) != (OUTPUT_SIZE, HIDDEN_SIZE):
        raise ValueError(
            "fc2.weight must have shape "
            f"({OUTPUT_SIZE}, {HIDDEN_SIZE}), "
            f"but received {tuple(fc2_weight.shape)}."
        )

    if tuple(fc2_bias.shape) != (OUTPUT_SIZE,):
        raise ValueError(
            "fc2.bias must have shape "
            f"({OUTPUT_SIZE},), "
            f"but received {tuple(fc2_bias.shape)}."
        )

    for name, weights in (
        ("fc1.weight", fc1_weight),
        ("fc2.weight", fc2_weight),
    ):
        minimum = weights.min().item()
        maximum = weights.max().item()

        if minimum < WEIGHT_MIN or maximum > WEIGHT_MAX:
            raise ValueError(
                f"{name} contains values outside signed int4: "
                f"{minimum} to {maximum}."
            )

    for name, biases in (
        ("fc1.bias", fc1_bias),
        ("fc2.bias", fc2_bias),
    ):
        minimum = biases.min().item()
        maximum = biases.max().item()

        if minimum < BIAS_MIN or maximum > BIAS_MAX:
            raise ValueError(
                f"{name} contains values outside signed int8: "
                f"{minimum} to {maximum}."
            )


def integer_mac_layer(
    inputs: torch.Tensor,
    weights: torch.Tensor,
    biases: torch.Tensor,
) -> torch.Tensor:
    """
    Simulate one FPGA MAC layer.

    Hardware operation for every output neuron:

        accumulator = signed 8-bit bias

        for every input:
            accumulator = accumulator + input * weight

    Specifications:
        input:       unsigned 4-bit
        weight:      signed 4-bit
        bias:        signed 8-bit
        accumulator: signed 16-bit

    Returns:
        Signed integer accumulator values with shape:

            [batch_size, number_of_output_neurons]
    """
    inputs = inputs.to(torch.int32)
    weights = weights.to(torch.int32)
    biases = biases.to(torch.int32)

    if inputs.min().item() < INPUT_MIN:
        raise ValueError("MAC inputs contain negative values.")

    if inputs.max().item() > INPUT_MAX:
        raise ValueError(
            "MAC inputs exceed the unsigned 4-bit maximum of 15."
        )

    batch_size = inputs.shape[0]
    output_size = weights.shape[0]
    input_size = weights.shape[1]

    if inputs.shape[1] != input_size:
        raise ValueError(
            f"Input has {inputs.shape[1]} values, "
            f"but the layer expects {input_size}."
        )

    # Sign-extend the int8 bias into the 16-bit accumulator.
    accumulators = biases.unsqueeze(0).expand(
        batch_size,
        output_size
    ).clone()

    # Simulate the sequential FPGA MAC operations.
    #
    # weights[:, index]:
    #     one weight from every output neuron
    #
    # inputs[:, index]:
    #     one input value from every image
    for index in range(input_size):
        current_inputs = inputs[:, index].unsqueeze(1)
        current_weights = weights[:, index].unsqueeze(0)

        products = current_inputs * current_weights

        accumulators = accumulators + products
        accumulators = wrap_to_int16(accumulators)

    return accumulators


def saturated_relu_uint4(
    accumulators: torch.Tensor
) -> torch.Tensor:
    """
    Match the SystemVerilog ReLU exactly:

        negative input -> 0
        input above 15 -> 15
        otherwise      -> input[3:0]

    Output values are stored as int32, but remain within uint4 range 0-15.
    """
    return torch.clamp(
        accumulators,
        min=RELU_MIN,
        max=RELU_MAX
    ).to(torch.int32)


def integer_forward(
    images: torch.Tensor,
    model_state: dict
) -> tuple[torch.Tensor, torch.Tensor]:
    """
    Run the complete FPGA-equivalent MLP forward pass.

    Returns:
        output_scores:
            Ten signed 16-bit scores for every image.

        hidden_activations:
            Sixteen unsigned 4-bit hidden-layer values.
    """
    fc1_accumulators = integer_mac_layer(
        inputs=images,
        weights=model_state["fc1.weight"],
        biases=model_state["fc1.bias"],
    )

    hidden_activations = saturated_relu_uint4(
        fc1_accumulators
    )

    fc2_accumulators = integer_mac_layer(
        inputs=hidden_activations,
        weights=model_state["fc2.weight"],
        biases=model_state["fc2.bias"],
    )

    # No ReLU after the output layer.
    return fc2_accumulators, hidden_activations


def evaluate_integer_model(
    test_loader: DataLoader,
    model_state: dict
) -> float:
    """Evaluate FPGA-equivalent accuracy on the full MNIST test set."""
    correct = 0
    total = 0

    hidden_min = None
    hidden_max = None
    output_min = None
    output_max = None

    with torch.no_grad():
        for images, labels in test_loader:
            output_scores, hidden_activations = integer_forward(
                images,
                model_state
            )

            predictions = torch.argmax(
                output_scores,
                dim=1
            )

            total += labels.size(0)
            correct += (
                predictions == labels
            ).sum().item()

            batch_hidden_min = hidden_activations.min().item()
            batch_hidden_max = hidden_activations.max().item()
            batch_output_min = output_scores.min().item()
            batch_output_max = output_scores.max().item()

            if hidden_min is None:
                hidden_min = batch_hidden_min
                hidden_max = batch_hidden_max
                output_min = batch_output_min
                output_max = batch_output_max
            else:
                hidden_min = min(hidden_min, batch_hidden_min)
                hidden_max = max(hidden_max, batch_hidden_max)
                output_min = min(output_min, batch_output_min)
                output_max = max(output_max, batch_output_max)

    accuracy = 100.0 * correct / total

    print("Observed integer ranges:")
    print(
        f"  Hidden activations: "
        f"{hidden_min} to {hidden_max}"
    )
    print(
        f"  Output scores:      "
        f"{output_min} to {output_max}"
    )
    print()

    return accuracy


def main() -> None:
    if not QUANTIZED_MODEL_PATH.exists():
        raise FileNotFoundError(
            f"Could not find:\n"
            f"{QUANTIZED_MODEL_PATH}\n\n"
            f"Run train.py and quantize.py first."
        )

    model_state = torch.load(
        QUANTIZED_MODEL_PATH,
        map_location="cpu",
        weights_only=True
    )

    validate_quantized_model(model_state)

    # Integer output gives int8 storage containing uint4 values 0-15.
    _, test_dataset = load_mnist(
        output_type="int"
    )

    test_loader = DataLoader(
        test_dataset,
        batch_size=BATCH_SIZE,
        shuffle=False
    )

    print("========== FPGA Integer Inference ==========")
    print()
    print(f"Test images:         {len(test_dataset)}")
    print("Input:               unsigned 4-bit")
    print("Weights:             signed 4-bit")
    print("Biases:              signed 8-bit")
    print("Accumulator:         signed 16-bit")
    print("Hidden activation:   saturated unsigned 4-bit")
    print("Output activation:   none")
    print()

    accuracy = evaluate_integer_model(
        test_loader,
        model_state
    )

    print("========== Results ==========")
    print(f"FPGA integer accuracy: {accuracy:.2f}%")


if __name__ == "__main__":
    main()