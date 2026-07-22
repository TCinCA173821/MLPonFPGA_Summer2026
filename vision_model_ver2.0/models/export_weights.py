from pathlib import Path
import torch


MODEL_PATH = Path("models/quantized_model.pth")
OUTPUT_PATH = Path("models/weights.c")

IMAGE_PIXEL_COUNT = 196
HIDDEN_NODE_COUNT = 16
OUTPUT_NODE_COUNT = 10
PACKET_BYTE_COUNT = 4


def load_checkpoint(model_path: Path) -> dict:
    checkpoint = torch.load(
        model_path,
        map_location="cpu",
        weights_only=True,
    )

    if not isinstance(checkpoint, dict):
        raise TypeError(
            f"Expected a dictionary checkpoint, got {type(checkpoint).__name__}."
        )

    required_keys = {
        "fc1.weight",
        "fc1.bias",
        "fc2.weight",
        "fc2.bias",
    }

    missing_keys = required_keys - checkpoint.keys()

    if missing_keys:
        raise KeyError(
            "Checkpoint is missing required keys: "
            + ", ".join(sorted(missing_keys))
        )

    return checkpoint


def validate_tensor_shapes(checkpoint: dict) -> None:
    expected_shapes = {
        "fc1.weight": (HIDDEN_NODE_COUNT, IMAGE_PIXEL_COUNT),
        "fc1.bias": (HIDDEN_NODE_COUNT,),
        "fc2.weight": (OUTPUT_NODE_COUNT, HIDDEN_NODE_COUNT),
        "fc2.bias": (OUTPUT_NODE_COUNT,),
    }

    for name, expected_shape in expected_shapes.items():
        tensor = checkpoint[name]

        if not isinstance(tensor, torch.Tensor):
            raise TypeError(f"{name} is not a torch.Tensor.")

        actual_shape = tuple(tensor.shape)

        if actual_shape != expected_shape:
            raise ValueError(
                f"{name} has shape {actual_shape}, "
                f"expected {expected_shape}."
            )


def tensor_to_int_list(tensor: torch.Tensor, name: str) -> list[int]:
    values = tensor.detach().cpu().to(torch.int32).flatten().tolist()

    if any(value < -128 or value > 127 for value in values):
        raise ValueError(f"{name} contains values outside int8_t range.")

    return [int(value) for value in values]


def validate_int4_weights(tensor: torch.Tensor, name: str) -> None:
    minimum = int(tensor.min().item())
    maximum = int(tensor.max().item())

    if minimum < -8 or maximum > 7:
        raise ValueError(
            f"{name} contains values outside signed INT4 range: "
            f"min={minimum}, max={maximum}."
        )


def pack_layer_one(fc1_weight: torch.Tensor) -> list[int]:
    """
    Pack hidden-layer weights in Pico packet order.

    W_AB convention:
        A = hidden output node
        B = image pixel input
    """
    packed = []

    for first_hidden_node in range(0, HIDDEN_NODE_COUNT, PACKET_BYTE_COUNT):
        for pixel_index in range(IMAGE_PIXEL_COUNT):
            for lane in range(PACKET_BYTE_COUNT):
                hidden_node = first_hidden_node + lane
                packed.append(
                    int(fc1_weight[hidden_node, pixel_index].item())
                )

    expected_count = IMAGE_PIXEL_COUNT * HIDDEN_NODE_COUNT

    if len(packed) != expected_count:
        raise RuntimeError(
            f"layer_one has {len(packed)} values, expected {expected_count}."
        )

    return packed


def pack_layer_two(fc2_weight: torch.Tensor) -> list[int]:
    """
    Pack output-layer weights in Pico packet order.

    W_AB convention:
        A = output node
        B = hidden-layer input node

    The Pico inserts two zero lanes for the final output group.
    """
    packed = []

    for first_output_node in (0, 4):
        for hidden_index in range(HIDDEN_NODE_COUNT):
            for lane in range(PACKET_BYTE_COUNT):
                output_node = first_output_node + lane
                packed.append(
                    int(fc2_weight[output_node, hidden_index].item())
                )

    for hidden_index in range(HIDDEN_NODE_COUNT):
        packed.append(int(fc2_weight[8, hidden_index].item()))
        packed.append(int(fc2_weight[9, hidden_index].item()))

    expected_count = HIDDEN_NODE_COUNT * OUTPUT_NODE_COUNT

    if len(packed) != expected_count:
        raise RuntimeError(
            f"layer_two has {len(packed)} values, expected {expected_count}."
        )

    return packed


def pack_biases(
    fc1_bias: torch.Tensor,
    fc2_bias: torch.Tensor,
) -> list[int]:
    hidden_biases = tensor_to_int_list(fc1_bias, "fc1.bias")
    output_biases = tensor_to_int_list(fc2_bias, "fc2.bias")
    packed = hidden_biases + output_biases

    expected_count = HIDDEN_NODE_COUNT + OUTPUT_NODE_COUNT

    if len(packed) != expected_count:
        raise RuntimeError(
            f"biases has {len(packed)} values, expected {expected_count}."
        )

    return packed


def format_values(values: list[int], values_per_line: int = 16) -> str:
    lines = []

    for start in range(0, len(values), values_per_line):
        chunk = values[start:start + values_per_line]
        lines.append("    " + ", ".join(str(value) for value in chunk) + ",")

    return "\n".join(lines)


def format_layer_one(layer_one: list[int]) -> str:
    lines = []
    group_size = IMAGE_PIXEL_COUNT * PACKET_BYTE_COUNT

    for group_index in range(HIDDEN_NODE_COUNT // PACKET_BYTE_COUNT):
        start = group_index * group_size
        end = start + group_size
        first_node = group_index * PACKET_BYTE_COUNT
        last_node = first_node + PACKET_BYTE_COUNT - 1

        lines.append(
            f"    /* Hidden nodes {first_node}-{last_node}, pixels 0-195. */"
        )
        lines.append(format_values(layer_one[start:end]))

    return "\n".join(lines)


def format_layer_two(layer_two: list[int]) -> str:
    lines = []
    full_group_size = HIDDEN_NODE_COUNT * PACKET_BYTE_COUNT

    lines.append("    /* Output nodes 0-3, hidden inputs 0-15. */")
    lines.append(format_values(layer_two[0:full_group_size]))

    lines.append("    /* Output nodes 4-7, hidden inputs 0-15. */")
    lines.append(
        format_values(
            layer_two[full_group_size:2 * full_group_size]
        )
    )

    lines.append(
        "    /* Output nodes 8-9, hidden inputs 0-15. "
        "Pico adds two zero lanes. */"
    )
    lines.append(format_values(layer_two[2 * full_group_size:]))

    return "\n".join(lines)


def write_weights_c(
    output_path: Path,
    layer_one: list[int],
    layer_two: list[int],
    biases: list[int],
) -> None:
    contents = f'''#include "weights.h"

/*
 * Auto-generated from quantized_model.pth by export_weights.py.
 *
 * layer_one and layer_two contain signed INT4 weights stored in int8_t
 * elements. form_packet() converts each value to its low four-bit
 * two's-complement representation and places it in the upper nibble.
 *
 * Biases are stored as signed INT8 values.
 */

const int8_t layer_one[LAYER_ONE_WEIGHT_COUNT] = {{
{format_layer_one(layer_one)}
}};

const int8_t layer_two[LAYER_TWO_WEIGHT_COUNT] = {{
{format_layer_two(layer_two)}
}};

const int8_t biases[BIAS_COUNT] = {{
    /* Hidden biases 0-15, followed by output biases 0-9. */
{format_values(biases)}
}};
'''

    output_path.write_text(contents, encoding="utf-8")


def main() -> None:
    checkpoint = load_checkpoint(MODEL_PATH)
    validate_tensor_shapes(checkpoint)

    fc1_weight = checkpoint["fc1.weight"]
    fc1_bias = checkpoint["fc1.bias"]
    fc2_weight = checkpoint["fc2.weight"]
    fc2_bias = checkpoint["fc2.bias"]

    validate_int4_weights(fc1_weight, "fc1.weight")
    validate_int4_weights(fc2_weight, "fc2.weight")

    layer_one = pack_layer_one(fc1_weight)
    layer_two = pack_layer_two(fc2_weight)
    biases = pack_biases(fc1_bias, fc2_bias)

    write_weights_c(
        OUTPUT_PATH,
        layer_one,
        layer_two,
        biases,
    )

    print(f"Generated: {OUTPUT_PATH}")
    print(f"layer_one values: {len(layer_one)}")
    print(f"layer_two values: {len(layer_two)}")
    print(f"bias values:      {len(biases)}")


if __name__ == "__main__":
    main()
