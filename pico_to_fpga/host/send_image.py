"""
Send one 14x14 grayscale image to the Raspberry Pi Pico over USB CDC.

USB frame:
    Bytes 0-3: ASCII header "IMG1"
    Bytes 4-199: 196 pixels, one four-bit pixel per byte

Each transmitted pixel is between 0 and 15.
"""

import argparse
import time
from pathlib import Path

import serial
from PIL import Image


IMAGE_WIDTH = 14
IMAGE_HEIGHT = 14
IMAGE_PIXEL_COUNT = IMAGE_WIDTH * IMAGE_HEIGHT
IMAGE_HEADER = b"IMG1"

# USB CDC does not actually depend on this baud rate, but PySerial requires one.
USB_BAUD_RATE = 115200


def prepare_image(image_path: Path, invert: bool) -> bytes:
    """Load, resize, grayscale, and quantize an image to four bits."""

    with Image.open(image_path) as original:
        grayscale = original.convert("L")

        resized = grayscale.resize(
            (IMAGE_WIDTH, IMAGE_HEIGHT),
            Image.Resampling.LANCZOS
        )

    eight_bit_pixels = list(resized.getdata())

    if invert:
        eight_bit_pixels = [255 - pixel for pixel in eight_bit_pixels]

    # Convert each unsigned eight-bit pixel from 0-255 to four bits, 0-15.
    four_bit_pixels = bytes(pixel >> 4 for pixel in eight_bit_pixels)

    if len(four_bit_pixels) != IMAGE_PIXEL_COUNT:
        raise ValueError(
            f"Expected {IMAGE_PIXEL_COUNT} pixels, "
            f"but generated {len(four_bit_pixels)}."
        )

    return four_bit_pixels


def read_available_messages(pico: serial.Serial, duration: float) -> list[str]:
    """Read and display Pico status messages for a limited time."""

    messages = []
    deadline = time.monotonic() + duration

    while time.monotonic() < deadline:
        raw_message = pico.readline()

        if not raw_message:
            continue

        message = raw_message.decode(errors="replace").strip()

        if message:
            messages.append(message)
            print(f"Pico: {message}")

    return messages


def wait_for_transfer(pico: serial.Serial, timeout: float) -> None:
    """Wait until the Pico reports success or the timeout expires."""

    image_received = False
    deadline = time.monotonic() + timeout

    while time.monotonic() < deadline:
        raw_message = pico.readline()

        if not raw_message:
            continue

        message = raw_message.decode(errors="replace").strip()

        if not message:
            continue

        print(f"Pico: {message}")

        if message == "IMAGE_OK":
            image_received = True

        if message == "TRANSFER_OK":
            print("Inference data transfer completed successfully.")
            return

    if image_received:
        raise TimeoutError(
            "The Pico received the image but did not finish the transfer. "
            "Check the FPGA NXTPCKT signal and Pico-to-FPGA wiring."
        )

    raise TimeoutError(
        "The Pico did not report IMAGE_OK. Check the COM port, firmware, "
        "USB connection, and IMG1 image format."
    )


def send_image(
    port: str,
    image_path: Path,
    invert: bool,
    transfer_timeout: float
) -> None:
    """Prepare an image and send its complete frame to the Pico."""

    pixels = prepare_image(image_path, invert)
    frame = IMAGE_HEADER + pixels

    print(f"Image: {image_path}")
    print(f"USB port: {port}")
    print(f"Pixels: {len(pixels)}")
    print(f"Frame size: {len(frame)} bytes")

    with serial.Serial(
        port=port,
        baudrate=USB_BAUD_RATE,
        timeout=0.1,
        write_timeout=5
    ) as pico:
        # Give the USB CDC connection time to become active.
        time.sleep(1)

        # READY may already be waiting in the USB receive buffer.
        read_available_messages(pico, duration=1)

        # Send the header and pixels as one binary frame.
        pico.write(frame)
        pico.flush()

        print("Image frame sent. Waiting for the Pico and FPGA...")
        wait_for_transfer(pico, transfer_timeout)


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Send a 14x14 four-bit grayscale image to the Pico."
    )

    parser.add_argument(
        "--port",
        required=True,
        help="Pico USB serial port, such as COM5."
    )

    parser.add_argument(
        "--image",
        required=True,
        type=Path,
        help="Path to the image file."
    )

    parser.add_argument(
        "--invert",
        action="store_true",
        help="Invert black and white before sending."
    )

    parser.add_argument(
        "--timeout",
        type=float,
        default=30.0,
        help="Seconds to wait for TRANSFER_OK."
    )

    arguments = parser.parse_args()

    if not arguments.image.is_file():
        parser.error(f"Image file does not exist: {arguments.image}")

    try:
        send_image(
            port=arguments.port,
            image_path=arguments.image,
            invert=arguments.invert,
            transfer_timeout=arguments.timeout
        )
    except (serial.SerialException, TimeoutError, ValueError) as error:
        print(f"ERROR: {error}")
        raise SystemExit(1)


if __name__ == "__main__":
    main()