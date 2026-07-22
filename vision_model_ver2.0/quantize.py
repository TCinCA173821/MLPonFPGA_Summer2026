from pathlib import Path

import torch


# --------------------------------------------------
# File paths
# --------------------------------------------------

BASE_DIR = Path(__file__).resolve().parent
MODEL_DIR = BASE_DIR / "models"

FLOAT_MODEL_PATH = MODEL_DIR / "best_qat_model.pth"
QUANTIZED_MODEL_PATH = MODEL_DIR / "quantized_model.pth"


# --------------------------------------------------
# Hardware bit requirements
# --------------------------------------------------

WEIGHT_BITS = 4
BIAS_BITS = 8

WEIGHT_MIN = -(2 ** (WEIGHT_BITS - 1))       # -8
WEIGHT_MAX = (2 ** (WEIGHT_BITS - 1)) - 1   # 7

BIAS_MIN = -(2 ** (BIAS_BITS - 1))          # -128
BIAS_MAX = (2 ** (BIAS_BITS - 1)) - 1       # 127


def quantize_weights(
    weights: torch.Tensor
) -> tuple[torch.Tensor, torch.Tensor]:
    """
    Quantize floating-point weights into signed 4-bit integers.

    PyTorch has no native int4 tensor type, so the values are stored
    using int8. Every stored value is restricted to the int4 range
    [-8, 7].

    Returns:
        quantized_weights:
            int8 tensor containing signed int4 values.

        weight_scale:
            Floating-point scale used to map between the float weights
            and integer weights.
    """
    weights = weights.detach().cpu().float()

    max_abs_weight = weights.abs().max()

    if max_abs_weight.item() == 0:
        weight_scale = torch.tensor(1.0, dtype=torch.float32)
    else:
        # Use the positive int4 limit of 7 for symmetric quantization.
        weight_scale = max_abs_weight / WEIGHT_MAX

    quantized_weights = torch.round(
        weights / weight_scale
    )

    quantized_weights = torch.clamp(
        quantized_weights,
        WEIGHT_MIN,
        WEIGHT_MAX
    )

    return quantized_weights.to(torch.int8), weight_scale


def quantize_biases(
    biases: torch.Tensor,
    weight_scale: torch.Tensor
) -> tuple[torch.Tensor, int]:
    """
    Convert floating-point biases into integer MAC accumulator units.

    The FPGA performs:

        accumulator = bias_int
        accumulator += input_int * weight_int

    Because the input pixels already use integer values from 0 to 15,
    their numerical input scale is 1.

    The weight relationship is approximately:

        weight_float = weight_int * weight_scale

    Therefore, the accumulator-compatible bias is:

        bias_int = round(bias_float / weight_scale)

    The resulting bias is clipped to the signed 8-bit hardware range.

    Returns:
        quantized_biases:
            int8 tensor restricted to [-128, 127].

        clipped_count:
            Number of biases that exceeded the int8 range.
    """
    biases = biases.detach().cpu().float()

    unbounded_biases = torch.round(
        biases / weight_scale
    )

    clipped_mask = (
        (unbounded_biases < BIAS_MIN)
        | (unbounded_biases > BIAS_MAX)
    )

    clipped_count = clipped_mask.sum().item()

    quantized_biases = torch.clamp(
        unbounded_biases,
        BIAS_MIN,
        BIAS_MAX
    )

    return quantized_biases.to(torch.int8), clipped_count


def print_parameter_summary(
    layer_name: str,
    weights: torch.Tensor,
    biases: torch.Tensor,
    weight_scale: torch.Tensor,
    clipped_bias_count: int
) -> None:
    """Print useful information about one quantized layer."""
    print(f"{layer_name}:")
    print(
        f"  Weight shape:     "
        f"{tuple(weights.shape)}"
    )
    print(
        f"  Weight range:     "
        f"{weights.min().item()} to {weights.max().item()}"
    )
    print(
        f"  Weight scale:     "
        f"{weight_scale.item():.8f}"
    )
    print(
        f"  Bias shape:       "
        f"{tuple(biases.shape)}"
    )
    print(
        f"  Bias range:       "
        f"{biases.min().item()} to {biases.max().item()}"
    )
    print(
        f"  Clipped biases:   "
        f"{clipped_bias_count}/{biases.numel()}"
    )
    print()


def main() -> None:
    MODEL_DIR.mkdir(parents=True, exist_ok=True)

    if not FLOAT_MODEL_PATH.exists():
        raise FileNotFoundError(
            f"Could not find the trained model:\n"
            f"{FLOAT_MODEL_PATH}\n\n"
            f"Run train.py before running quantize.py."
        )

    float_state = torch.load(
        FLOAT_MODEL_PATH,
        map_location="cpu",
        weights_only=True
    )

    required_keys = {
        "fc1.weight",
        "fc1.bias",
        "fc2.weight",
        "fc2.bias",
    }

    missing_keys = required_keys - set(float_state.keys())

    if missing_keys:
        raise KeyError(
            "The float model is missing these parameters: "
            f"{sorted(missing_keys)}"
        )

    # --------------------------------------------------
    # First layer
    # --------------------------------------------------

    fc1_weight_int4, fc1_weight_scale = quantize_weights(
        float_state["fc1.weight"]
    )

    fc1_bias_int8, fc1_clipped_biases = quantize_biases(
        float_state["fc1.bias"],
        fc1_weight_scale
    )

    # --------------------------------------------------
    # Second layer
    # --------------------------------------------------

    fc2_weight_int4, fc2_weight_scale = quantize_weights(
        float_state["fc2.weight"]
    )

    fc2_bias_int8, fc2_clipped_biases = quantize_biases(
        float_state["fc2.bias"],
        fc2_weight_scale
    )

    # --------------------------------------------------
    # Save FPGA-compatible integer parameters
    # --------------------------------------------------

    quantized_state = {
        # Hardware parameters
        "fc1.weight": fc1_weight_int4,
        "fc1.bias": fc1_bias_int8,
        "fc2.weight": fc2_weight_int4,
        "fc2.bias": fc2_bias_int8,

        # Metadata useful for analysis and debugging
        "fc1.weight_scale": fc1_weight_scale,
        "fc2.weight_scale": fc2_weight_scale,

        "input_bits": INPUT_BITS,
        "weight_bits": WEIGHT_BITS,
        "bias_bits": BIAS_BITS,
        "accumulator_bits": 16,
        "hidden_activation_bits": 4,
    }

    torch.save(
        quantized_state,
        QUANTIZED_MODEL_PATH
    )

    print("========== Quantization Results ==========")
    print()

    print_parameter_summary(
        layer_name="FC1",
        weights=fc1_weight_int4,
        biases=fc1_bias_int8,
        weight_scale=fc1_weight_scale,
        clipped_bias_count=fc1_clipped_biases
    )

    print_parameter_summary(
        layer_name="FC2",
        weights=fc2_weight_int4,
        biases=fc2_bias_int8,
        weight_scale=fc2_weight_scale,
        clipped_bias_count=fc2_clipped_biases
    )

    print("Hardware format:")
    print("  Inputs:             unsigned 4-bit, 0 to 15")
    print("  Weights:            signed 4-bit, -8 to 7")
    print("  Biases:             signed 8-bit, -128 to 127")
    print("  Accumulator:        signed 16-bit")
    print("  Hidden activation:  unsigned 4-bit, 0 to 15")
    print()
    print(f"Saved quantized model to:")
    print(QUANTIZED_MODEL_PATH)


INPUT_BITS = 4


if __name__ == "__main__":
    main()