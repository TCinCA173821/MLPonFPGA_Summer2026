# MNIST Digit Collector

A single-file, offline web app for collecting a handwritten-digit dataset in
MNIST format. Built for walking around a classroom with an iPad Pro and handing
it to people to draw on with a finger or Apple Pencil.

Everything lives in `index.html` — no build step, no backend, no CDN
dependencies. Open it in a browser and it works.

## Output format

Every saved sample is a **28×28, 8-bit grayscale PNG** (PNG colour type 0),
black background, white digit — byte-for-byte the format MNIST uses, so images
drop straight into `vision_model_ver2.0/preprocess.py`:

```python
from PIL import Image
from preprocess import preprocess_image_uint4

flat = preprocess_image_uint4(Image.open("maria-lopez_7_01.png"))  # (196,) uint4
```

### Preprocessing pipeline (on Save)

1. Read the drawing canvas and find the bounding box of all drawn pixels.
2. Crop to that box with a small margin.
3. Resize to fit a **20×20 box, aspect ratio preserved**, using area averaging
   so edges are anti-aliased like real MNIST digits.
4. Paste onto a 28×28 black field, centred by **centre of mass**.

Steps 3 and 4 are MNIST's actual normalisation convention. Aspect ratio matters:
stretching a `1` to a square 20×20 would make it several times too wide and no
MNIST-trained model would recognise it. A **Bounding box** toggle in the side
panel switches step 4 to plain geometric centring if you want to compare.

Stroke width scales with the canvas, so a normally-sized digit lands at roughly
2–3 px once downsampled. Thin / Medium / Thick presets are available.

## Files and storage

Filenames follow `{person-slug}_{digit}_{trial}.png`, e.g. `maria-lopez_7_01.png`.
The slug is lowercased with non-alphanumeric runs collapsed to `-`; the trial
counter is per (person, digit) and auto-increments, so repeated draws never
overwrite each other. An empty name field saves as `anon`.

Saved images and a manifest live in **IndexedDB**, so an accidental reload
mid-session loses nothing — counts and trial numbers are restored on load.
The current person's name is kept in `localStorage` for the same reason.

**Download all (.zip)** bundles every PNG plus `manifest.csv`
(`filename, person, digit, timestamp`). The PNG encoder and ZIP writer are both
implemented inline, so export needs no network and no library.

**Erase all data** clears IndexedDB behind a confirmation prompt. Export first.

## Running it on the iPad

Serve it over HTTP rather than opening it from the Files app — iOS Safari gives
`file://` pages an opaque origin, and IndexedDB is unreliable there. Any static
host works (GitHub Pages, or `python3 -m http.server` on a laptop on the same
wifi).

Load the page once and it needs no further network access; the drawing, saving
and export loop is entirely local. Use **Share → Add to Home Screen** to run it
fullscreen without Safari's chrome. Note that without a service worker (which
would mean a second file) a cold launch with no network is not guaranteed to
work, so load it once while you still have a connection.

Both landscape and portrait keep the canvas, preview and Save button on screen
without scrolling.
