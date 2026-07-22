from pathlib import Path

import torch
import torch.nn as nn
import torch.nn.functional as F
from torch.utils.data import DataLoader

from preprocess import load_mnist
from train import MLP


# --------------------------------------------------
# File paths
# --------------------------------------------------

BASE_DIR = Path(__file__).resolve().parent
MODEL_DIR = BASE_DIR / "models"

FLOAT_MODEL_PATH = MODEL_DIR / "best_model.pth"
QAT_MODEL_PATH = MODEL_DIR / "best_qat_model.pth"


# --------------------------------------------------
# Training settings
# --------------------------------------------------

BATCH_SIZE = 64
NUM_EPOCHS = 20
LEARNING_RATE = 0.0001

WEIGHT_BITS = 4
BIAS_BITS = 8

WEIGHT_MIN = -8
WEIGHT_MAX = 7

BIAS_MIN = -128
BIAS_MAX = 127

HIDDEN_MIN = 0
HIDDEN_MAX = 15


def straight_through_quantize(
    tensor: torch.Tensor,
    scale: torch.Tensor,
    qmin: int,
    qmax: int,
) -> torch.Tensor:
    """
    Fake-quantize a tensor while allowing gradients to pass through.

    Forward pass:
        tensor -> divide by scale -> round -> clamp

    Backward pass:
        Treat quantization approximately like the identity function.

    The returned values behave like integers during the forward pass,
    but remain floating-point tensors so PyTorch can backpropagate.
    """
    quantized = torch.round(tensor / scale)
    quantized = torch.clamp(quantized, qmin, qmax)

    # Straight-through estimator:
    # forward value = quantized
    # gradient behaves approximately as though no rounding occurred
    return tensor / scale + (
        quantized - tensor / scale
    ).detach()


def calculate_weight_scale(
    weights: torch.Tensor
) -> torch.Tensor:
    """
    Calculate the same symmetric int4 scale used by quantize.py.

    The scale is detached because it is quantization metadata,
    not a trainable model parameter.
    """
    max_abs = weights.detach().abs().max()

    if max_abs.item() == 0:
        return torch.tensor(
            1.0,
            device=weights.device,
            dtype=weights.dtype,
        )

    return max_abs / WEIGHT_MAX


def fake_quantize_weight_int4(
    weights: torch.Tensor
) -> tuple[torch.Tensor, torch.Tensor]:
    """
    Simulate signed 4-bit FPGA weights.

    Returns:
        fake integer weights stored as float tensors
        weight scale
    """
    scale = calculate_weight_scale(weights)

    weights_int4 = straight_through_quantize(
        tensor=weights,
        scale=scale,
        qmin=WEIGHT_MIN,
        qmax=WEIGHT_MAX,
    )

    return weights_int4, scale


def fake_quantize_bias_int8(
    biases: torch.Tensor,
    weight_scale: torch.Tensor,
) -> torch.Tensor:
    """
    Simulate the signed 8-bit bias loaded into the FPGA accumulator.

    Your FPGA computes:

        accumulator = bias_int
        accumulator += input_int * weight_int

    Inputs already use integer values from 0 to 15, so the bias must
    be converted into the same accumulator units as the int4 weights:

        bias_int = round(bias_float / weight_scale)
    """
    return straight_through_quantize(
        tensor=biases,
        scale=weight_scale,
        qmin=BIAS_MIN,
        qmax=BIAS_MAX,
    )


def fake_saturated_relu_uint4(
    values: torch.Tensor
) -> torch.Tensor:
    """
    Simulate your SystemVerilog ReLU:

        negative -> 0
        above 15 -> 15
        otherwise -> rounded integer value

    The output remains float32 for backpropagation, but its forward
    values are restricted to unsigned 4-bit integers from 0 to 15.
    """
    quantized = torch.round(values)
    quantized = torch.clamp(
        quantized,
        HIDDEN_MIN,
        HIDDEN_MAX,
    )

    # Straight-through estimator
    return values + (quantized - values).detach()


class QATMLP(MLP):
    """
    MLP that stores trainable floating-point parameters but simulates
    the FPGA's integer arithmetic during its forward pass.
    """

    def forward(self, x: torch.Tensor) -> torch.Tensor:
        # Input values are already restricted to integer values 0-15,
        # although they are stored as float32 for PyTorch training.

        # --------------------------------------------------
        # First layer: uint4 input x int4 weight + int8 bias
        # --------------------------------------------------

        fc1_weight_int4, fc1_weight_scale = (
            fake_quantize_weight_int4(self.fc1.weight)
        )

        fc1_bias_int8 = fake_quantize_bias_int8(
            self.fc1.bias,
            fc1_weight_scale,
        )

        x = F.linear(
            x,
            fc1_weight_int4,
            fc1_bias_int8,
        )

        # Match the FPGA's saturated 4-bit ReLU.
        x = fake_saturated_relu_uint4(x)

        # --------------------------------------------------
        # Second layer: uint4 input x int4 weight + int8 bias
        # --------------------------------------------------

        fc2_weight_int4, fc2_weight_scale = (
            fake_quantize_weight_int4(self.fc2.weight)
        )

        fc2_bias_int8 = fake_quantize_bias_int8(
            self.fc2.bias,
            fc2_weight_scale,
        )

        x = F.linear(
            x,
            fc2_weight_int4,
            fc2_bias_int8,
        )

        # No ReLU after the output layer.
        return x


def evaluate_qat_model(
    model: nn.Module,
    test_loader: DataLoader,
) -> float:
    """Evaluate using the quantization-aware forward pass."""
    model.eval()

    correct = 0
    total = 0

    with torch.no_grad():
        for images, labels in test_loader:
            outputs = model(images)

            predictions = torch.argmax(
                outputs,
                dim=1,
            )

            total += labels.size(0)
            correct += (
                predictions == labels
            ).sum().item()

    return 100.0 * correct / total


def print_quantization_status(model: QATMLP) -> None:
    """Print the current integer ranges and bias clipping status."""
    with torch.no_grad():
        fc1_weights, fc1_scale = fake_quantize_weight_int4(
            model.fc1.weight
        )

        fc1_bias_unclipped = torch.round(
            model.fc1.bias / fc1_scale
        )

        fc2_weights, fc2_scale = fake_quantize_weight_int4(
            model.fc2.weight
        )

        fc2_bias_unclipped = torch.round(
            model.fc2.bias / fc2_scale
        )

        fc1_clipped = (
            (fc1_bias_unclipped < BIAS_MIN)
            | (fc1_bias_unclipped > BIAS_MAX)
        ).sum().item()

        fc2_clipped = (
            (fc2_bias_unclipped < BIAS_MIN)
            | (fc2_bias_unclipped > BIAS_MAX)
        ).sum().item()

        print("Quantization status:")
        print(
            f"  FC1 weight integers: "
            f"{fc1_weights.min().item():.0f} to "
            f"{fc1_weights.max().item():.0f}"
        )
        print(
            f"  FC1 bias clipping:   "
            f"{fc1_clipped}/{model.fc1.bias.numel()}"
        )
        print(
            f"  FC2 weight integers: "
            f"{fc2_weights.min().item():.0f} to "
            f"{fc2_weights.max().item():.0f}"
        )
        print(
            f"  FC2 bias clipping:   "
            f"{fc2_clipped}/{model.fc2.bias.numel()}"
        )


def main() -> None:
    torch.manual_seed(0)

    MODEL_DIR.mkdir(
        parents=True,
        exist_ok=True,
    )

    if not FLOAT_MODEL_PATH.exists():
        raise FileNotFoundError(
            f"Could not find the float model:\n"
            f"{FLOAT_MODEL_PATH}\n\n"
            f"Run train.py before running qatuning.py."
        )

    # Values are 0-15 but stored as float32 so gradients work.
    train_dataset, test_dataset = load_mnist(
        output_type="float"
    )

    train_loader = DataLoader(
        train_dataset,
        batch_size=BATCH_SIZE,
        shuffle=True,
    )

    test_loader = DataLoader(
        test_dataset,
        batch_size=BATCH_SIZE,
        shuffle=False,
    )

    model = QATMLP()

    float_state = torch.load(
        FLOAT_MODEL_PATH,
        map_location="cpu",
        weights_only=True,
    )

    model.load_state_dict(float_state)

    criterion = nn.CrossEntropyLoss()

    # Adam is useful here because QAT fine-tuning can have noisy gradients.
    optimizer = torch.optim.Adam(
        model.parameters(),
        lr=LEARNING_RATE,
    )

    scheduler = torch.optim.lr_scheduler.StepLR(
        optimizer,
        step_size=10,
        gamma=0.5,
    )

    initial_accuracy = evaluate_qat_model(
        model,
        test_loader,
    )

    print("========== QAT Fine-Tuning ==========")
    print(f"Initial QAT accuracy: {initial_accuracy:.2f}%")
    print()

    best_accuracy = initial_accuracy

    # Save the initial state in case later epochs become worse.
    torch.save(
        model.state_dict(),
        QAT_MODEL_PATH,
    )

    for epoch in range(NUM_EPOCHS):
        model.train()

        total_loss = 0.0

        for images, labels in train_loader:
            optimizer.zero_grad()

            outputs = model(images)
            loss = criterion(outputs, labels)

            loss.backward()

            # Helps prevent unstable updates during low-bit training.
            torch.nn.utils.clip_grad_norm_(
                model.parameters(),
                max_norm=5.0,
            )

            optimizer.step()

            total_loss += loss.item()

        average_loss = total_loss / len(train_loader)

        test_accuracy = evaluate_qat_model(
            model,
            test_loader,
        )

        current_lr = optimizer.param_groups[0]["lr"]

        print(
            f"Epoch [{epoch + 1}/{NUM_EPOCHS}]"
        )
        print(f"Loss:         {average_loss:.4f}")
        print(f"QAT Accuracy: {test_accuracy:.2f}%")
        print(f"Learning Rate:{current_lr:.6f}")

        if test_accuracy > best_accuracy:
            best_accuracy = test_accuracy

            torch.save(
                model.state_dict(),
                QAT_MODEL_PATH,
            )

            print("------ New best QAT model saved! ------")

        print()

        scheduler.step()

    print("========== QAT Complete ==========")
    print(f"Initial QAT accuracy: {initial_accuracy:.2f}%")
    print(f"Best QAT accuracy:    {best_accuracy:.2f}%")
    print(f"Saved model:          {QAT_MODEL_PATH}")
    print()

    best_qat_state = torch.load(
        QAT_MODEL_PATH,
        map_location="cpu",
        weights_only=True,
    )

    model.load_state_dict(best_qat_state)

    print_quantization_status(model)


if __name__ == "__main__":
    main()