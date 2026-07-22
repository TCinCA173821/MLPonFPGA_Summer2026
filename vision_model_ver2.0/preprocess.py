import numpy as np
import torch
from PIL import Image
from torch.utils.data import Dataset
from torchvision import datasets


IMG_SIZE = 14
INPUT_MIN = 0
INPUT_MAX = 15


def resize_image(
    image: Image.Image,
    size: int = IMG_SIZE
) -> Image.Image:
    """Resize an image to the network's required dimensions."""
    return image.resize(
        (size, size),
        Image.Resampling.LANCZOS
    )


def quantize_to_uint4(image: Image.Image) -> np.ndarray:
    """
    Quantize an 8-bit grayscale image from 0-255 to unsigned 4-bit values 0-15.

    The values are stored in uint8 because NumPy has no native uint4 type,
    but every value is guaranteed to fit within 4 bits.
    """
    image_array = np.asarray(image, dtype=np.uint8)

    image_uint4 = image_array >> 4

    return np.clip(
        image_uint4,
        INPUT_MIN,
        INPUT_MAX
    ).astype(np.uint8)


def flatten_image(image_uint4: np.ndarray) -> np.ndarray:
    """Flatten a 14x14 image into 196 input values."""
    return image_uint4.reshape(-1)


def preprocess_image_uint4(image: Image.Image) -> np.ndarray:
    """
    Prepare an image for FPGA-style integer inference.

    Output:
        NumPy array with shape (196,)
        dtype: uint8
        values: 0-15
    """
    image = image.convert("L")
    image_14x14 = resize_image(image)
    image_uint4 = quantize_to_uint4(image_14x14)
    image_flat = flatten_image(image_uint4)

    return image_flat


def preprocess_image_float(image: Image.Image) -> torch.Tensor:
    """
    Prepare an image for floating-point PyTorch training.

    The numerical values are still limited to 0-15, but they are stored as
    float32 so they can be passed through nn.Linear.
    """
    image_uint4 = preprocess_image_uint4(image)

    return torch.tensor(
        image_uint4,
        dtype=torch.float32
    )


def preprocess_image_int(image: Image.Image) -> torch.Tensor:
    """
    Prepare an image for FPGA-equivalent integer inference.

    PyTorch has no int4 tensor type, so the 4-bit values are stored in int8.
    Every value remains within the unsigned 4-bit range 0-15.
    """
    image_uint4 = preprocess_image_uint4(image)

    return torch.tensor(
        image_uint4,
        dtype=torch.int8
    )


# Keep this name for compatibility with existing demo-image code.
def preprocess_image(image: Image.Image) -> np.ndarray:
    return preprocess_image_uint4(image)


class PreprocessedMNIST(Dataset):
    def __init__(
        self,
        original_dataset,
        output_type: str = "float"
    ):
        """
        output_type:
            "float" -> float32 tensor for training with nn.Linear
            "int"   -> int8 tensor containing uint4 values for FPGA simulation
        """
        if output_type not in {"float", "int"}:
            raise ValueError(
                "output_type must be either 'float' or 'int'"
            )

        self.original_dataset = original_dataset
        self.output_type = output_type

    def __len__(self) -> int:
        return len(self.original_dataset)

    def __getitem__(self, index):
        image, label = self.original_dataset[index]

        if self.output_type == "float":
            image_tensor = preprocess_image_float(image)
        else:
            image_tensor = preprocess_image_int(image)

        return image_tensor, label


def load_mnist(
    data_dir: str = "./data",
    output_type: str = "float"
):
    """
    Load preprocessed MNIST datasets.

    For training:
        load_mnist(output_type="float")

    For integer FPGA simulation:
        load_mnist(output_type="int")
    """
    original_train = datasets.MNIST(
        root=data_dir,
        train=True,
        download=True
    )

    original_test = datasets.MNIST(
        root=data_dir,
        train=False,
        download=True
    )

    train_dataset = PreprocessedMNIST(
        original_train,
        output_type=output_type
    )

    test_dataset = PreprocessedMNIST(
        original_test,
        output_type=output_type
    )

    return train_dataset, test_dataset


if __name__ == "__main__":
    float_train, _ = load_mnist(output_type="float")
    int_train, _ = load_mnist(output_type="int")

    float_image, label = float_train[0]
    int_image, _ = int_train[0]

    print("Label:", label)

    print("\nTraining tensor:")
    print("Shape:", float_image.shape)
    print("Data type:", float_image.dtype)
    print("Minimum:", float_image.min().item())
    print("Maximum:", float_image.max().item())

    print("\nFPGA simulation tensor:")
    print("Shape:", int_image.shape)
    print("Storage type:", int_image.dtype)
    print("Minimum:", int_image.min().item())
    print("Maximum:", int_image.max().item())