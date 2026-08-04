from pathlib import Path

import torch
from PIL import Image, UnidentifiedImageError

from integer_inference import integer_forward, validate_quantized_model
from preprocess import preprocess_image_int


BASE_DIR = Path(__file__).resolve().parent
MODEL_PATH = BASE_DIR / "models" / "quantized_model.pth"
CUSTOM_IMAGE_DIR = BASE_DIR / "demo_images" / "custom"

DIGIT_COUNT = 10
IMAGE_SUFFIXES = {".png", ".jpg", ".jpeg", ".bmp", ".gif", ".tif", ".tiff"}


def load_model() -> dict:
    if not MODEL_PATH.exists():
        raise FileNotFoundError(
            f"Could not find the quantized model:\n{MODEL_PATH}\n\n"
            "Run quantize.py first."
        )

    model_state = torch.load(
        MODEL_PATH,
        map_location="cpu",
        weights_only=True,
    )
    validate_quantized_model(model_state)
    return model_state


def find_images(folder: Path) -> list[Path]:
    return sorted(
        path
        for path in folder.rglob("*")
        if path.is_file() and path.suffix.lower() in IMAGE_SUFFIXES
    )


def predict_image(image_path: Path, model_state: dict) -> int:
    with Image.open(image_path) as image:
        image_tensor = preprocess_image_int(image).unsqueeze(0)

    with torch.no_grad():
        output_scores, _ = integer_forward(image_tensor, model_state)

    return int(torch.argmax(output_scores, dim=1).item())


def evaluate_custom_images(
    model_state: dict,
) -> tuple[torch.Tensor, list[tuple[Path, int, int]], list[Path]]:
    confusion = torch.zeros(

        
        (DIGIT_COUNT, DIGIT_COUNT),
        dtype=torch.int64,
    )
    mistakes = []
    unreadable = []

    for true_digit in range(DIGIT_COUNT):
        digit_folder = CUSTOM_IMAGE_DIR / str(true_digit)

        if not digit_folder.is_dir():
            raise FileNotFoundError(
                f"Missing digit folder: {digit_folder}"
            )

        for image_path in find_images(digit_folder):
            try:

                predicted_digit = predict_image(image_path, model_state)
            except (OSError, UnidentifiedImageError):
                unreadable.append(image_path)

                continue

            confusion[true_digit, predicted_digit] += 1

            if predicted_digit != true_digit:
                mistakes.append(
                    (image_path, true_digit, predicted_digit)
                )

    return confusion, mistakes, unreadable



def print_report(
    confusion: torch.Tensor,
    mistakes: list[tuple[Path, int, int]],
    unreadable: list[Path],
) -> None:
    total_images = int(confusion.sum().item())

    if total_images == 0:
        raise RuntimeError(
            "No supported images were found under:\n"
            f"{CUSTOM_IMAGE_DIR}\n\n"

            "Put each image in the folder matching its true digit."
        )

    total_correct = int(torch.diag(confusion).sum().item())
    total_errors = total_images - total_correct

    print("========== Custom Image Accuracy ==========")
    print(f"Images tested:    {total_images}")
    print(f"Correct:          {total_correct}")
    print(f"Errors:           {total_errors}")


    print(f"Overall accuracy: {100.0 * total_correct / total_images:.2f}%")
    print()

    print("Per-digit results:")
    print("Digit  Images  Correct  Errors  Accuracy")

    for digit in range(DIGIT_COUNT):
        row = confusion[digit]
        image_count = int(row.sum().item())

        correct = int(row[digit].item())
        errors = image_count - correct

        if image_count:
            accuracy_text = f"{100.0 * correct / image_count:6.2f}%"
        else:
            accuracy_text = "   N/A "

        print(
            f"  {digit}    {image_count:4d}    {correct:4d}"
            f"    {errors:4d}     {accuracy_text}"
        )

    print()
    print("Confusion matrix (rows=true, columns=predicted):")
    print("       " + " ".join(f"{digit:4d}" for digit in range(DIGIT_COUNT)))

    for true_digit in range(DIGIT_COUNT):
        values = " ".join(
            f"{int(value):4d}" for value in confusion[true_digit]
        )
        print(f"True {true_digit}: {values}")

    print()
    print("Misclassified files:")

    if mistakes:
        for image_path, true_digit, predicted_digit in mistakes:
            relative_path = image_path.relative_to(CUSTOM_IMAGE_DIR)
            print(
                f"  {relative_path}: true={true_digit}, "
                f"predicted={predicted_digit}"
            )
    else:
        print("  None")

    if unreadable:
        print()
        print("Unreadable image files (not included in accuracy):")
        for image_path in unreadable:
            print(f"  {image_path.relative_to(CUSTOM_IMAGE_DIR)}")

    digit_results = []

    for digit in range(DIGIT_COUNT):
        image_count = int(confusion[digit].sum().item())

        if image_count:
            correct = int(confusion[digit, digit].item())
            accuracy = 100.0 * correct / image_count
            digit_results.append((accuracy, digit, image_count))

    strongest = max(digit_results)
    weakest = min(digit_results)

    confusion_pairs = []

    for true_digit in range(DIGIT_COUNT):
        for predicted_digit in range(DIGIT_COUNT):
            if true_digit == predicted_digit:
                continue

            count = int(confusion[true_digit, predicted_digit].item())

            if count:
                confusion_pairs.append(
                    (count, true_digit, predicted_digit)
                )

    confusion_pairs.sort(reverse=True)

    print()
    print("========== Summary Report ==========")
    print(
        f"Overall accuracy: {100.0 * total_correct / total_images:.2f}% "
        f"({total_correct}/{total_images})"
    )
    print()
    print("Per-digit results:")
    print("Digit  Total  Correct  Errors  Accuracy  Error share")

    for digit in range(DIGIT_COUNT):
        row = confusion[digit]
        total = int(row.sum().item())
        correct = int(row[digit].item())
        errors = total - correct
        accuracy = 100.0 * correct / total if total else 0.0
        error_share = (
            100.0 * errors / total_errors if total_errors else 0.0
        )

        print(
            f"  {digit}    {total:4d}    {correct:4d}    {errors:4d}"
            f"     {accuracy:6.2f}%      {error_share:6.2f}%"
        )

    print()
    print(
        f"Strongest digit: {strongest[1]} "
        f"({strongest[0]:.2f}% over {strongest[2]} images)"
    )
    print(
        f"Weakest digit:   {weakest[1]} "
        f"({weakest[0]:.2f}% over {weakest[2]} images)"
    )

    if confusion_pairs:
        print("Most common errors:")
        for count, true_digit, predicted_digit in confusion_pairs[:5]:
            print(
                f"  True {true_digit} predicted as "
                f"{predicted_digit}: {count} images"
            )
    else:
        print("Most common errors: none")


def main() -> None:
    model_state = load_model()
    confusion, mistakes, unreadable = evaluate_custom_images(model_state)
    print_report(confusion, mistakes, unreadable)


if __name__ == "__main__":
    main()
