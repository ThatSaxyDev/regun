"""Package web atlases at the resolution RegunArt decodes in the browser."""

import json
import sys
from pathlib import Path

from PIL import Image


def main():
    art = Path(sys.argv[1]) / "assets" / "assets" / "art"
    manifest = json.loads((art / "manifest.json").read_text())
    before = after = 0
    for name, metadata in manifest.items():
        path = art / f"{name}.png"
        before += path.stat().st_size
        with Image.open(path) as image:
            width = metadata["decodeWidth"]
            # Loadout uses the original floor art directly for its backdrop.
            if width < image.width and not name.endswith("_floor"):
                height = max(1, round(image.height * width / image.width))
                resized = image.convert("RGBA").resize(
                    (width, height), Image.Resampling.BILINEAR
                )
                resized.save(path, optimize=True)
        after += path.stat().st_size
    print(f"Web art: {before / 1e6:.1f} MB → {after / 1e6:.1f} MB")


if __name__ == "__main__":
    main()
