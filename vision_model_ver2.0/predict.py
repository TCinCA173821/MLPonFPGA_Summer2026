from pathlib import Path

import torch
from PIL import Image

from preprocess import preprocess_image_int
from integer_inference import (
    integer_forward,
    validate_quantized_model,
)


# --------------------------------------------------
# File paths
# --------------------------------------------------

BASE_DIR = Path(__file__).resolve().parent

IMAGE_PATH = BASE_DIR / "demo_images" / "input.png"
MODEL_PATH = BASE_DIR / "models" / "quantized_model.pth"


def main() -> None:
    if not IMAGE_PATH.exists():
        raise FileNotFoundError(
            f"Could not find the input image:\n{IMAGE_PATH}"
        )

    if not MODEL_PATH.exists():
        raise FileNotFoundError(
            f"Could not find the quantized model:\n"
            f"{MODEL_PATH}\n\n"
            f"Run train.py and quantize.py first."
        )

    # --------------------------------------------------
    # Load and preprocess image
    # --------------------------------------------------

    image = Image.open(IMAGE_PATH).convert("L")

    print("Original image size:", image.size)

    # Produces 196 integer values in the range 0-15.
    #
    # PyTorch stores them as int8 because it has no normal
    # unsigned int4 tensor type.
    image_tensor = preprocess_image_int(image)

    # Add the batch dimension:
    #
    # [196] -> [1, 196]
    image_tensor = image_tensor.unsqueeze(0)

    print("Processed tensor shape:", image_tensor.shape)
    print("Processed tensor type:", image_tensor.dtype)
    print(
        "Processed input range:",
        image_tensor.min().item(),
        "to",
        image_tensor.max().item(),
    )

    # --------------------------------------------------
    # Load FPGA-compatible integer parameters
    # --------------------------------------------------

    model_state = torch.load(
        MODEL_PATH,
        map_location="cpu",
        weights_only=True,
    )

    validate_quantized_model(model_state)

    # --------------------------------------------------
    # FPGA-equivalent integer prediction
    # --------------------------------------------------

    with torch.no_grad():
        output_scores, hidden_activations = integer_forward(
            image_tensor,
            model_state,
        )

        prediction = torch.argmax(
            output_scores,
            dim=1,
        ).item()

    # print()
    # print("Hidden activations:")
    # print(hidden_activations.squeeze(0))

    print()
    print("Integer output scores:")
    print(output_scores.squeeze(0))

    print()
    print("Predicted digit:", prediction)


if __name__ == "__main__":
    main()