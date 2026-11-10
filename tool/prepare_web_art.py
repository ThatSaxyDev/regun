"""Package web atlases at the resolution RegunArt decodes in the browser."""

import json
import sys
from pathlib import Path

from PIL import Image

# Bachs redirects the browser to the configured success URL and appends
# `?checkout_id=`.
#
# The checkout runs in a tab the game opened, so the right end to the payment is
# for that tab to close and leave the player where they were. Loading the game
# here instead would produce a second live game in the checkout tab, which is
# both confusing and a duplicate session. A tab opened by script may close
# itself, so `window.close()` is attempted first; if the browser refuses (for
# example the URL was opened by hand), the page says so rather than silently
# stranding the player in a duplicate game.
RETURN_PAGE = """<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<meta name="robots" content="noindex">
<meta http-equiv="Cache-Control" content="no-store">
<title>Regun</title>
<script>
  (function () {
    // Close as early and as often as the browser allows. This page must never
    // load the game: doing so is what produced a second game in the checkout
    // tab. `window.open('', '_self')` first is the documented workaround that
    // lets a script-opened tab close itself even after a cross-origin redirect.
    function shut() {
      try { window.open('', '_self'); } catch (error) {}
      try { window.close(); } catch (error) {}
    }
    shut();
    document.addEventListener('DOMContentLoaded', shut);
    window.addEventListener('load', function () {
      shut();
      setTimeout(function () {
        if (window.closed) return;
        try { if (window.opener) window.opener.focus(); } catch (error) {}
        var nudge = document.getElementById('nudge');
        if (nudge) nudge.style.display = 'block';
      }, 300);
    });
  })();
</script>
<style>
  html,body{margin:0;height:100%;background:#12100e;color:#e1ba78;
  font-family:system-ui,sans-serif;display:grid;place-items:center;text-align:center}
  p{margin:0 0 14px;font-size:15px;line-height:1.5;max-width:34rem;padding:0 20px}
  button{font:inherit;color:#12100e;background:#e1ba78;border:0;border-radius:6px;
  padding:10px 18px;cursor:pointer}
  #nudge{display:none}
</style>
</head>
<body>
  <div>
    <p id="nudge">Payment received. Close this tab to return to your game —
    your Scrap has been added there.</p>
    <button onclick="window.close()">Close tab</button>
  </div>
</body>
</html>
"""

# `/checkout-return/` is the canonical path. `/scrap-return/` is kept because an
# older return URL may still be configured. A fresh path also means no browser
# can serve a cached copy of a previous, broken version of this page.
RETURN_PATHS = ("checkout-return", "scrap-return")


def write_return_page(root: Path) -> None:
    for name in RETURN_PATHS:
        target = root / name / "index.html"
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(RETURN_PAGE, encoding="utf-8")


def main():
    root = Path(sys.argv[1])
    write_return_page(root)
    art = root / "assets" / "assets" / "art"
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