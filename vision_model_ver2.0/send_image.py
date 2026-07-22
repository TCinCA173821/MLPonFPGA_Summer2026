from pathlib import Path
import argparse
import time

import numpy as np
import serial
from PIL import Image

from preprocess import preprocess_image_uint4


BASE_DIR = Path(__file__).resolve().parent
DEFAULT_IMAGE = BASE_DIR / "demo_images" / "input.png"

IMAGE_HEADER = b"IMG1"
PIXEL_COUNT = 14 * 14
TIMEOUT_SECONDS = 15


def receive_user_inputs() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Send a 14x14 image to the Raspberry Pi Pico."
    )

    parser.add_argument(
        "--port",
        required=True,
        help="Pico USB COM port, for example COM5.",
    )

    parser.add_argument(
        "--image",
        type=Path,
        default=DEFAULT_IMAGE,
        help="Path to the image that will be sent.",
    )

    return parser.parse_args()


def prepare_pixels(image_path: Path) -> np.ndarray:
    """Load and preprocess an image into 196 unsigned 4-bit pixels."""

    if not image_path.is_file():
        raise FileNotFoundError(
            f"Could not find image: {image_path}"
        )

    with Image.open(image_path) as image:
        pixels = preprocess_image_uint4(image)

    if pixels.shape != (PIXEL_COUNT,):
        raise ValueError(
            f"Expected {PIXEL_COUNT} pixels, "
            f"but received shape {pixels.shape}."
        )

    if pixels.dtype != np.uint8:
        raise TypeError(
            f"Expected uint8 storage, but received {pixels.dtype}."
        )

    minimum = int(pixels.min())
    maximum = int(pixels.max())

    if minimum < 0 or maximum > 15:
        raise ValueError(
            f"Pixel values must be between 0 and 15, "
            f"but received {minimum} to {maximum}."
        )

    return pixels


def wait_for_message(
    pico: serial.Serial,
    expected_message: bytes,
) -> None:
    """Wait for a particular status message from the Pico."""

    deadline = time.monotonic() + TIMEOUT_SECONDS

    while time.monotonic() < deadline:
        message = pico.readline().strip()

        if not message:
            continue

        print(
            "Pico:",
            message.decode("ascii", errors="replace"),
        )

        if message == expected_message:
            return

    expected_text = expected_message.decode("ascii")

    raise TimeoutError(
        f"Timed out waiting for {expected_text}."
    )


def send_pixels(
    port: str,
    pixels: np.ndarray,
) -> None:
    """Send the IMG1 header and 196 raw pixel bytes to the Pico."""

    payload = IMAGE_HEADER + pixels.tobytes()

    print(f"Opening {port}...")

    with serial.Serial(
        port=port,
        baudrate=115200,
        timeout=0.25,
        write_timeout=TIMEOUT_SECONDS,
    ) as pico:

        wait_for_message(pico, b"READY")

        bytes_written = pico.write(payload)
        pico.flush()

        if bytes_written != len(payload):
            raise IOError(
                f"Expected to send {len(payload)} bytes, "
                f"but only sent {bytes_written}."
            )

        print(
            f"Sent {bytes_written} bytes: "
            "4-byte header + 196 pixels."
        )

        wait_for_message(pico, b"IMAGE_OK")

    print("The Pico received the complete image.")


def main() -> None:
    args = receive_user_inputs()

    print("Image:", args.image)

    pixels = prepare_pixels(args.image)

    print(
        f"Prepared {pixels.size} pixels "
        f"with values from {pixels.min()} to {pixels.max()}."
    )

    send_pixels(args.port, pixels)


if __name__ == "__main__":
    main()