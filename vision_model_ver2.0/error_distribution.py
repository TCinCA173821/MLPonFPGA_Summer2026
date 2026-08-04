from pathlib import Path

import torch
from torch.utils.data import DataLoader

from integer_inference import integer_forward, validate_quantized_model
from preprocess import load_mnist


BASE_DIR = Path(__file__).resolve().parent
MODEL_PATH = BASE_DIR / "models" / "quantized_model.pth"

BATCH_SIZE = 256
DIGIT_COUNT = 10


def evaluate_errors() -> torch.Tensor:
    """Return a confusion matrix indexed by [true digit, predicted digit]."""
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

    _, test_dataset = load_mnist(output_type="int")
    test_loader = DataLoader(
        test_dataset,
        batch_size=BATCH_SIZE,
        shuffle=False,
    )

    confusion = torch.zeros(
        (DIGIT_COUNT, DIGIT_COUNT),
        dtype=torch.int64,
    )

    with torch.no_grad():
        for images, labels in test_loader:
            output_scores, _ = integer_forward(images, model_state)
            predictions = torch.argmax(output_scores, dim=1)

            for true_digit, predicted_digit in zip(labels, predictions):
                confusion[true_digit, predicted_digit] += 1

    return confusion


def print_report(confusion: torch.Tensor) -> None:
    total_images = int(confusion.sum().item())
    total_correct = int(torch.diag(confusion).sum().item())
    total_errors = total_images - total_correct

    print("========== Quantized Test Error Distribution ==========")
    print(f"Test images:      {total_images}")
    print(f"Correct:          {total_correct}")
    print(f"Errors:           {total_errors}")
    print(f"Overall accuracy: {100.0 * total_correct / total_images:.2f}%")
    print()

    print("Per-digit results:")
    print("Digit  Total  Correct  Errors  Accuracy  Error share")

    for digit in range(DIGIT_COUNT):
        row = confusion[digit]
        total = int(row.sum().item())
        correct = int(row[digit].item())
        errors = total - correct
        accuracy = 100.0 * correct / total
        error_share = (
            100.0 * errors / total_errors if total_errors else 0.0
        )

        print(
            f"  {digit}    {total:4d}    {correct:4d}    {errors:4d}"
            f"     {accuracy:6.2f}%      {error_share:6.2f}%"
        )

    print()
    print("Wrong predictions for each true digit:")

    for true_digit in range(DIGIT_COUNT):
        mistakes = []

        for predicted_digit in range(DIGIT_COUNT):
            if predicted_digit == true_digit:
                continue

            count = int(confusion[true_digit, predicted_digit].item())
            if count:
                mistakes.append((count, predicted_digit))

        mistakes.sort(reverse=True)
        description = ", ".join(
            f"{predicted_digit}: {count}"
            for count, predicted_digit in mistakes
        )

        print(f"True {true_digit} -> {description or 'no errors'}")

    print()
    print("Confusion matrix (rows=true, columns=predicted):")
    print("       " + " ".join(f"{digit:4d}" for digit in range(DIGIT_COUNT)))

    for true_digit in range(DIGIT_COUNT):
        values = " ".join(
            f"{int(value):4d}" for value in confusion[true_digit]
        )
        print(f"True {true_digit}: {values}")


def main() -> None:
    confusion = evaluate_errors()
    print_report(confusion)


if __name__ == "__main__":
    main()
