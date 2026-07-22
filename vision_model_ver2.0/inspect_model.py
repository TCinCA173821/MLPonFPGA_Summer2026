import torch

MODEL_PATH = "models/quantized_model.pth"

data = torch.load(
    MODEL_PATH,
    map_location="cpu",
    weights_only=True
)

print("Loaded object type:", type(data))

for key, value in data.items():
    print(f"\n{key}")
    print("  Python type:", type(value))

    if isinstance(value, torch.Tensor):
        print("  shape:", value.shape)
        print("  dtype:", value.dtype)
        print("  first few values:", value.flatten()[:10])
    else:
        print("  value:", value)