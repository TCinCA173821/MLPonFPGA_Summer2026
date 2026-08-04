from pathlib import Path
import argparse

import numpy as np
from PIL import Image

BASE_DIR = Path(__file__).resolve().parent
DEFAULT_OUTPUT_PATH = BASE_DIR / "demo_images" / "224input.png"
EXPECTED_INPUT_SIZE = (224, 224)
OUTPUT_SIZE = (28, 28)


def parse_arguments() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Downsample a 224x224 image into the model's quantized "
            "28x28 image format."
        )
    )
    parser.add_argument(
        "image",
        type=Path,
        help="Path to the 224x224 source image.",
    )
    parser.add_argument(
        "--output",
        type=Path,
        default=DEFAULT_OUTPUT_PATH,
        help=(
            "Output PNG path. Defaults to "
            "demo_images/224input.png."
        ),
    )
    return parser.parse_args()


def convert_image(input_path: Path, output_path: Path) -> None:
    if not input_path.is_file():
        raise FileNotFoundError(f"Could not find image: {input_path}")

    with Image.open(input_path) as image:
        if image.size != EXPECTED_INPUT_SIZE:
            raise ValueError(
                f"Expected a 224x224 image, but received "
                f"{image.width}x{image.height}."
            )

        image_28x28 = image.convert("L").resize(
            OUTPUT_SIZE,
            Image.Resampling.LANCZOS,
        )
        pixels_uint8 = np.asarray(image_28x28, dtype=np.uint8)
        pixels_uint4 = pixels_uint8 >> 4

    # Expand values 0-15 back across the PNG grayscale range 0-255.
    # Reading this PNG through the normal preprocessing pipeline preserves
    # the same 16 grayscale levels before it is reduced to 14x14.
    preview_pixels = (pixels_uint4 * 17).astype(np.uint8)
    output_image = Image.fromarray(preview_pixels, mode="L")

    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_image.save(output_path, format="PNG")

    print(f"Input:  {input_path}")
    print("Input size:  224x224")
    print(f"Output: {output_path}")
    print("Output size: 28x28")
    print(
        f"4-bit range: {int(pixels_uint4.min())} "
        f"to {int(pixels_uint4.max())}"
    )


def main() -> None:
    args = parse_arguments()
    convert_image(args.image, args.output)


if __name__ == "__main__":
    main()
