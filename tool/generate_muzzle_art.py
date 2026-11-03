"""Author Regun's three-frame ballistic flash as a small pixel atlas."""
from pathlib import Path
import random
from PIL import Image

palette = [
    (126, 54, 31, 145),
    (192, 79, 36, 220),
    (238, 132, 54, 255),
    (255, 187, 93, 255),
    (255, 225, 159, 255),
    (255, 247, 214, 255),
]
# Pixel envelopes for ignition, bloom, and the ragged end of the flash.
profiles = [
    [2, 3, 4, 5, 6, 9, 8, 9, 6, 8, 5, 6, 4, 5, 4, 3, 4, 3, 3, 2, 3, 2, 1, 2, 1, 1],
    [2, 3, 5, 6, 8, 9, 8, 7, 6, 8, 6, 5, 6, 4, 5, 4, 4, 3, 4, 3, 2, 2, 3, 2, 1, 1, 2, 1, 1, 1],
    [1, 2, 3, 4, 5, 6, 6, 4, 5, 3, 4, 3, 4, 2, 3, 2, 3, 2, 2, 2, 1, 2, 1, 1],
]
atlas = Image.new('RGBA', (96, 24))
for frame, profile in enumerate(profiles):
    rng = random.Random(701 + frame)
    for x, spread in enumerate(profile):
        center = 12 + (1 if x > 11 and frame == 1 else 0)
        for y in range(center - spread, center + spread + 1):
            edge = abs(y - center) / max(1, spread)
            if edge > .75 and x > 3 and rng.random() < .21:
                continue
            heat = 1 - edge * .74 - x * .021 - frame * .035
            heat += rng.uniform(-.11, .11)
            index = max(0, min(5, round(heat * 5)))
            atlas.putpixel((frame * 32 + x, y), palette[index])
    for x, y in [(8, 2), (12, 20), (17, 5), (22, 17), (28, 8)]:
        if x < len(profile) + 2:
            atlas.putpixel((frame * 32 + x, y + frame % 2), palette[(x + y) % 3])
atlas.save(Path(__file__).resolve().parents[1] / 'assets/art/effects/ballistic_flash.png')

# Frost expands in lumpy white vapor instead of following the flame silhouette.
frost = Image.new('RGBA', (96, 24))
for frame in range(3):
    rng = random.Random(953 + frame)
    lobes = [(3, 12, 4, 3), (8, 11, 7, 5),
             (13, 8, 7, 6), (16, 15, 8, 6),
             (21, 11, 8, 7), (25, 5, 5, 4), (26, 18, 5, 4)]
    for x in range(32):
        for y in range(24):
            value = max(1 - ((x - cx - frame) / (rx + frame)) ** 2
                        - ((y - cy) / (ry + frame)) ** 2
                        for cx, cy, rx, ry in lobes)
            value += rng.uniform(-.18, .14)
            if value < .06:
                continue
            alpha = min(255, round(125 + value * 160 - frame * 31))
            shade = max(0, min(37, round((1 - value) * 30 + rng.uniform(-4, 6))))
            frost.putpixel((frame * 32 + x, y),
                           (247 - shade, 252 - shade // 2, 255, alpha))
    for x, y in [(13, 3), (20, 2), (23, 20), (27, 9), (29, 15), (19, 19)]:
        x = min(30, x + frame)
        frost.putpixel((frame * 32 + x, y), (249, 255, 255, 245 - frame * 36))
        frost.putpixel((frame * 32 + x + 1, y), (165, 214, 238, 220 - frame * 36))
frost.save(Path(__file__).resolve().parents[1] / 'assets/art/effects/frost_flash.png')
