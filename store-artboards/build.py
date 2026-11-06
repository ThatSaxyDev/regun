"""Compose and validate Regun's landscape store artwork from Flutter captures."""
from argparse import ArgumentParser
from hashlib import sha256
from html import escape
import json
from pathlib import Path
from zipfile import ZIP_STORED, ZipFile

from PIL import Image, ImageDraw, ImageFont, ImageOps

PACK = Path(__file__).resolve().parent
ROOT = PACK.parent
PIXEL = ROOT / "assets/fonts/PressStart2P-Regular.ttf"
ORBITRON = ROOT / "assets/fonts/Orbitron-Bold.ttf"
ICON = ROOT / "app_icon/launcher.png"
SHELTER = ROOT / "assets/art/arenas/home_hideout_v2.png"
FLOOR = ROOT / "assets/art/arenas/breach_floor.png"
BONE = "#f0e5d0"
BRASS = "#d9ab6a"

SHOTS = (
    ("01-survival", "NO QUIET WAY OUT.", "SURVIVAL",
     "Rook fires a pump shotgun as scorpions and other enemies close in across the Breach."),
    ("02-weapons", "MAKE EVERY SHOT COUNT.", "ARSENAL",
     "The Arc Caster chains electricity through three enemies in the Foundry."),
    ("03-upgrades", "BUILD YOUR WAY THROUGH.", "UPGRADES",
     "A level-up offers Heavy Payload, Field Medic and Wide Burst during a Foundry run."),
    ("04-bosses", "TAKE THEM APART.", "BOSSES",
     "Rook takes on Lodestar, an armored boss with a connected chain of weapon sections."),
    ("05-loadout", "CHOOSE YOUR SURVIVOR.", "LOADOUT",
     "The loadout screen previews Harrow with a pump shotgun in the Foundry."),
    ("06-airdrop", "HOLD YOUR GROUND.", "AIRDROPS",
     "Rook defends the capture area around a supply pod while fighting off the horde."),
)
FORMATS = (
    ("iphone", "01-App-Store-iPhone-2556x1179", "App Store · iPhone", (2556, 1179)),
    ("ipad", "02-App-Store-iPad-2752x2064", "App Store · iPad", (2752, 2064)),
    ("macos", "11-App-Store-Mac-2880x1800", "App Store · Mac", (2880, 1800)),
    ("play", "03-Play-Phone-1920x1080", "Google Play · Phone", (1920, 1080)),
    ("duo-outer", "07-App-Store-Duo-Outer-2034x1398", "App Store · iPhone Duo outer", (2034, 1398)),
    ("play-tablet", "10-Play-Tablet-1920x1080", "Google Play · Tablet", (1920, 1080)),
    ("duo-inner", "08-App-Store-Duo-Inner-2853x2007", "App Store · iPhone Duo inner", (2853, 2007)),
)


def font(path, size):
    return ImageFont.truetype(str(path), size)


def apple_board(frame, headline, label, number):
    width, height = frame.size
    gutter = round(width * .028)
    screen_width = width - 2 * gutter
    header = round(height * .145)
    available_height = height - header - round(height * .023)
    screen = ImageOps.contain(frame, (screen_width, available_height), Image.Resampling.LANCZOS)
    x = (width - screen.width) // 2
    y = header
    texture = ImageOps.fit(Image.open(FLOOR).convert("RGB"), frame.size)
    board = Image.blend(Image.new("RGB", frame.size, "#1c1917"), texture, .25)
    draw = ImageDraw.Draw(board)
    draw.rectangle((x - 3, y - 3, x + screen.width + 2, y + screen.height + 2),
                   fill="#665443")
    board.paste(screen, (x, y))
    draw.line((x, y - 12, x + round(width * .035), y - 12), fill=BRASS, width=3)
    metadata = font(ORBITRON, round(width * .0105))
    title = font(PIXEL, round(width * .021))
    draw.text((x, round(header * .15)), f"REGUN  /  {label}", font=metadata,
              fill=BRASS, anchor="lt")
    draw.text((x + screen.width, round(header * .15)), f"{number:02} / 06",
              font=metadata, fill="#c5b6a4", anchor="rt")
    title_y = round(header * .45)
    assert draw.textlength(headline, font=title) <= screen.width
    assert draw.textbbox((x, title_y), headline, font=title, anchor="lt")[3] < y - 12
    draw.text((x, title_y), headline, font=title, fill=BONE, anchor="lt")
    return board


def feature_graphic():
    size = (1024, 500)
    image = ImageOps.fit(
        Image.open(SHELTER).convert("RGB"), size,
        method=Image.Resampling.LANCZOS, centering=(.5, .63),
    )
    draw = ImageDraw.Draw(image)
    draw.text((128, 188), "REGUN", fill="#110b0c", font=font(PIXEL, 64), anchor="lt",
              stroke_width=3)
    draw.text((128, 181), "REGUN", fill=BONE, font=font(PIXEL, 64), anchor="lt")
    draw.line((128, 249, 210, 249), fill=BRASS, width=3)
    draw.text((128, 271), "NO QUIET WAY OUT.", fill=BRASS, font=font(ORBITRON, 19),
              anchor="lt")
    return image


def app_store_header():
    size = (3840, 1646)
    board = ImageOps.fit(Image.open(SHELTER).convert("RGB"), size,
                         Image.Resampling.LANCZOS, centering=(.5, .64))
    draw = ImageDraw.Draw(board)
    draw.text((500, 670), "REGUN", font=font(PIXEL, 214), fill="#150d0d",
              anchor="lt", stroke_width=8)
    draw.text((500, 648), "REGUN", font=font(PIXEL, 214), fill=BONE, anchor="lt")
    draw.line((500, 885, 810, 885), fill=BRASS, width=9)
    draw.text((500, 944), "NO QUIET WAY OUT.", font=font(ORBITRON, 60),
              fill=BRASS, anchor="lt")
    return board


def app_store_search():
    size = (3840, 2560)
    texture = ImageOps.fit(Image.open(FLOOR).convert("RGB"), size)
    board = Image.blend(Image.new("RGB", size, "#1a1617"), texture, .32)
    source = PACK / "sources/iphone/04-bosses.png"
    with Image.open(source) as capture:
        screen = ImageOps.contain(capture.convert("RGB"), (3180, 1600),
                                  Image.Resampling.LANCZOS)
    x = (size[0] - screen.width) // 2
    y = 728
    draw = ImageDraw.Draw(board)
    draw.text((1920, 306), "REGUN", font=font(PIXEL, 158), fill=BONE, anchor="mt")
    draw.text((1920, 512), "TWIN-STICK SURVIVAL", font=font(ORBITRON, 60),
              fill=BRASS, anchor="mt")
    draw.rectangle((x - 5, y - 5, x + screen.width + 4, y + screen.height + 4),
                   fill="#8a694a")
    board.paste(screen, (x, y))
    return board


def export(image, folder, stem, size, source, alt, *, icon=False):
    mode = "RGBA" if icon else "RGB"
    assert size == (512, 512) if icon else size[0] > size[1]
    assert image.mode == mode and image.size == size
    folder = PACK / "exports" / folder
    folder.mkdir(parents=True, exist_ok=True)
    file = folder / f"{stem}.png"
    image.save(file, compress_level=3)
    with Image.open(file) as decoded:
        decoded.load()
        assert decoded.mode == mode and decoded.size == size
    data = file.read_bytes()
    assert data, file
    if icon or "-Play-" in folder.name:
        assert len(data) <= (1_048_576 if icon else 8_000_000), file
    return dict(file=str(file.relative_to(PACK)), width=size[0], height=size[1],
                source=source, alt=alt, bytes=len(data), sha256=sha256(data).hexdigest())


def gallery(groups):
    sections = []
    for title, rows in groups:
        cards = []
        for row in rows:
            file, alt = escape(row["file"]), escape(row["alt"], quote=True)
            caption = Path(row["file"]).stem.replace("-", " ").title()
            cards.append(
                f'<figure><a href="{file}"><img src="{file}" alt="{alt}"></a>'
                f'<figcaption>{caption} · {row["width"]} × {row["height"]}</figcaption></figure>'
            )
        sections.append(f'<section><h2>{title}</h2><div class="grid">{"".join(cards)}</div></section>')
    (PACK / "index.html").write_text("""<!doctype html>
<html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>Regun · Landscape store artwork</title>
<style>
body{margin:0;background:#171419;color:#f0e5d0;font:16px/1.5 system-ui,sans-serif}
main{max-width:1240px;margin:auto;padding:36px 24px 60px}
h1{font-size:clamp(2rem,5vw,3.5rem);line-height:1;margin:0 0 16px}
h2{font-size:1.25rem;margin:40px 0 12px;color:#d9ab6a}
p{max-width:65ch} a{color:#e6ba80}
.grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(min(100%,360px),1fr));gap:18px}
figure{margin:0}img{display:block;width:100%;height:auto;border:1px solid #504237}
figcaption{padding:8px 0;color:#c8b8a9}
</style>
<main><h1>Regun · Landscape store artwork</h1>
<p>Landscape screenshots and creative assets for Regun. Select any image to open the full PNG.</p>
<p><a href="Regun-Store-Artwork.zip">Download the PNG pack</a> ·
<a href="UPLOAD-GUIDE.md">Upload guide</a></p>
""" + "\n".join(sections) + "</main></html>\n", encoding="utf-8")


def screenshots(target, folder, size):
    rows = []
    gameplay_first = target.startswith("play") or target == "macos"
    order = [SHOTS[i] for i in (0, 1, 3, 5, 2, 4)] if gameplay_first else SHOTS
    for number, (name, headline, label, alt) in enumerate(order, start=1):
        source = PACK / "sources" / target / f"{name}.png"
        with Image.open(source) as raw:
            assert raw.size == size, source
            frame = raw.convert("RGB")
        art = frame if target.startswith("play") else apple_board(frame, headline, label, number)
        rows.append(export(art, folder, f"{number:02}-{name[3:]}", size,
                           str(source.relative_to(PACK)), alt))
    return rows


def creative_assets():
    groups = []
    groups.append(("Google Play · Feature graphic", [export(
        feature_graphic(), "04-Play-Feature-1024x500", "regun-feature", (1024, 500),
        str(SHELTER.relative_to(ROOT)),
        "Regun title beside Rook preparing a shotgun shell at an amber-lit workbench.",
    )]))
    groups.append(("App Store · Product Page Header", [export(
        app_store_header(), "05-App-Store-Header-3840x1646", "regun-header",
        (3840, 1646), str(SHELTER.relative_to(ROOT)),
        "Regun title beside Rook in his lamp-lit shelter.",
    )]))
    groups.append(("App Store · Search Results", [export(
        app_store_search(), "06-App-Store-Search-Results-3840x2560", "regun-search-results",
        (3840, 2560), "sources/iphone/04-bosses.png",
        "Regun twin-stick survival gameplay showing Rook fighting the segmented Lodestar boss.",
    )]))
    with Image.open(ICON) as launcher:
        icon = launcher.convert("RGBA").resize((512, 512), Image.Resampling.LANCZOS)
    groups.append(("Google Play · Listing icon", [export(
        icon, "09-Play-Icon-512x512", "regun-play-icon", (512, 512),
        str(ICON.relative_to(ROOT)), "Rook's helmet with a cyan visor and ochre scarf.",
        icon=True,
    )]))
    return groups


def main(mac_only=False):
    if mac_only:
        existing = {}
        for row in json.loads((PACK / "validation.json").read_text(encoding="utf-8")):
            folder = Path(row["file"]).parent.name
            existing.setdefault(folder, []).append(row)

    groups = []
    for target, folder, title, size in FORMATS:
        rows = existing[folder] if mac_only and target != "macos" else screenshots(target, folder, size)
        groups.append((title, rows))
    if mac_only:
        for folder, title in (
            ("04-Play-Feature-1024x500", "Google Play · Feature graphic"),
            ("05-App-Store-Header-3840x1646", "App Store · Product Page Header"),
            ("06-App-Store-Search-Results-3840x2560", "App Store · Search Results"),
            ("09-Play-Icon-512x512", "Google Play · Listing icon"),
        ):
            groups.append((title, existing[folder]))
    else:
        groups.extend(creative_assets())

    rows = [row for _, group in groups for row in group]
    assert len(rows) == 46
    for row in rows:
        file = PACK / row["file"]
        assert sha256(file.read_bytes()).hexdigest() == row["sha256"], file
    (PACK / "validation.json").write_text(json.dumps(rows, indent=2) + "\n", encoding="utf-8")
    gallery(groups)

    with ZipFile(PACK / "Regun-Store-Artwork.zip", "w", ZIP_STORED) as archive:
        for row in rows:
            archive.write(PACK / row["file"], Path(row["file"]).relative_to("exports"))
        for name in ("UPLOAD-GUIDE.md", "validation.json"):
            archive.write(PACK / name, name)
    with ZipFile(PACK / "Regun-Store-Artwork.zip") as archive:
        assert archive.testzip() is None
    print(f"Exported and verified {len(rows)} PNG assets.")


if __name__ == "__main__":
    parser = ArgumentParser(description=__doc__)
    parser.add_argument("--mac-only", action="store_true",
                        help="Refresh Mac screenshots and reuse existing exports for other stores.")
    main(mac_only=parser.parse_args().mac_only)
