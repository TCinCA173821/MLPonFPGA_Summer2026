import torch
import torch.nn as nn
from torch.utils.data import DataLoader

from preprocess import load_mnist


INPUT_SIZE = 196
HIDDEN_SIZE = 16
OUTPUT_SIZE = 10

BATCH_SIZE = 64
NUM_EPOCHS = 100
LEARNING_RATE = 0.001

MODEL_PATH = "models/best_model.pth"


class MLP(nn.Module):
    def __init__(self):
        super().__init__()

        self.fc1 = nn.Linear(INPUT_SIZE, HIDDEN_SIZE)
        self.relu = nn.ReLU()
        self.fc2 = nn.Linear(HIDDEN_SIZE, OUTPUT_SIZE)

    def forward(self, x):
        x = self.fc1(x)
        x = self.relu(x)
        x = self.fc2(x)

        return x


def evaluate_model(model, test_loader):
    model.eval()

    correct = 0
    total = 0

    with torch.no_grad():
        for images, labels in test_loader:
            outputs = model(images)

            predicted = torch.argmax(outputs, dim=1)

            total += labels.size(0)
            correct += (predicted == labels).sum().item()

    accuracy = 100.0 * correct / total

    return accuracy


def train_model():
    # Inputs contain values from 0 to 15, but they are stored as float32
    # so PyTorch's nn.Linear and backpropagation can be used.
    train_dataset, test_dataset = load_mnist(
        output_type="float"
    )

    train_loader = DataLoader(
        train_dataset,
        batch_size=BATCH_SIZE,
        shuffle=True
    )

    test_loader = DataLoader(
        test_dataset,
        batch_size=BATCH_SIZE,
        shuffle=False
    )

    model = MLP()

    criterion = nn.CrossEntropyLoss()

    optimizer = torch.optim.SGD(
        model.parameters(),
        lr=LEARNING_RATE
    )

    # Dynamic Learning Rate
    scheduler = torch.optim.lr_scheduler.StepLR(
        optimizer,
        step_size=40,
        gamma=0.5
    )

    best_accuracy = 0.0

    for epoch in range(NUM_EPOCHS):
        model.train()

        total_loss = 0.0

        for images, labels in train_loader:
            optimizer.zero_grad()

            outputs = model(images)
            loss = criterion(outputs, labels)

            loss.backward()
            optimizer.step()

            total_loss += loss.item()

        average_loss = total_loss / len(train_loader)

        test_accuracy = evaluate_model(
            model,
            test_loader
        )

        current_lr = optimizer.param_groups[0]["lr"]

        print(
            f"Epoch [{epoch + 1}/{NUM_EPOCHS}]"
        )
        print(f"Loss:          {average_loss:.4f}")
        print(f"Test Accuracy: {test_accuracy:.2f}%")
        print(f"Learning Rate: {current_lr:.6f}")

        if test_accuracy > best_accuracy:
            best_accuracy = test_accuracy

            torch.save(
                model.state_dict(),
                MODEL_PATH
            )

            print("------ New best float model saved! ------")

        print()

        scheduler.step()

    print("========== Training Complete ==========")
    print(f"Best test accuracy: {best_accuracy:.2f}%")
    print(f"Saved model: {MODEL_PATH}")


def main():
    torch.manual_seed(0)

    train_model()


if __name__ == "__main__":
    main()