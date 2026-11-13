r"""Make the minimap button's icon for each race: one signature plant from that race's own concept art.

  uv run --no-project --with pillow --with numpy python tools/homeland_icon.py <concept dir> [--preview <png>]

Reads concept_<Race>.png (the same 768 px concepts the caps and frames come from) and writes icon_<race>.tga
(the minimap button's, by your race) and icon.tga (the addon list's, one race's for everyone). Each icon is
64 x 64, the plant's square crop on the concept's own dark ground, which the addon masks to a circle. Each crop is
a centre and a side in concept pixels, chosen by eye from the concepts sheet. The preview shows every icon at 64
and at the button's 24 px, circle-masked, so you can judge them at the size they're seen.
"""
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
SIZE = 64
LIST_ICON = "Night_Elf"       # icon.tga, the addon list's icon (the TOC's IconTexture): one for every race
LIFT = 1.15                   # a little brightness, so the dark paint reads at 24 px over the minimap
# race -> (centre x, centre y, side), in concept pixels
CROPS = {
    "Human": (636, 636, 150),       # a dog rose at the bottom right
    "Dwarf": (676, 340, 200),       # heather spikes, right side
    "Night_Elf": (694, 164, 150),   # a white moonflower, top right
    "Gnome": (166, 584, 150),       # a glowing blue mushroom, bottom left
    "Orc": (140, 612, 150),         # a red desert flower, bottom left
    "Undead": (602, 562, 190),      # pale mushrooms, bottom right
    "Tauren": (628, 158, 140),      # a white feather, top right, inside the printed border
    "Troll": (646, 242, 170),       # a magenta orchid, right side
}


def icon(img, cx, cy, side):
    """Crops a square round (cx, cy) and resizes it to the icon size.

    Args:
        img: the concept, a PIL image.
        cx, cy: the crop's centre in concept pixels.
        side: the crop's side in concept pixels.

    Returns:
        A SIZE x SIZE RGBA image, fully opaque.
    """
    h = side // 2
    im = img.convert("RGB").crop((cx - h, cy - h, cx + h, cy + h)).resize((SIZE, SIZE), Image.LANCZOS)
    a = np.clip(np.asarray(im, dtype=float) * LIFT, 0, 255).astype(np.uint8)
    return Image.fromarray(np.dstack([a, np.full(a.shape[:2], 255, np.uint8)]), "RGBA")


def write_tga(im, path):
    """32-bit uncompressed TGA, top-left origin, as the game reads it."""
    a = np.asarray(im)
    head = bytes([0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0]) + im.width.to_bytes(2, "little") + \
        im.height.to_bytes(2, "little") + bytes([32, 0x28])
    path.write_bytes(head + a[..., [2, 1, 0, 3]].tobytes())


def circle(im):
    """Returns im masked to a circle, as the addon's portrait mask shows it."""
    m = Image.new("L", im.size, 0)
    ImageDraw.Draw(m).ellipse((0, 0, im.width - 1, im.height - 1), fill=255)
    out = im.copy()
    out.putalpha(m)
    return out


def main(src, preview=None):
    icons = {}
    for race, (cx, cy, side) in CROPS.items():
        icons[race] = icon(Image.open(Path(src) / f"concept_{race}.png"), cx, cy, side)
        write_tga(icons[race], ROOT / f"icon_{race.lower()}.tga")
    write_tga(icons[LIST_ICON], ROOT / "icon.tga")
    if preview:
        sheet = Image.new("RGBA", (len(icons) * 80, 120), (60, 66, 58, 255))   # a grassy minimap-ish ground
        for i, im in enumerate(icons.values()):
            sheet.alpha_composite(circle(im), (i * 80 + 8, 8))
            small = circle(im.resize((24, 24), Image.LANCZOS))
            sheet.alpha_composite(small, (i * 80 + 28, 84))
        sheet.save(preview)
    print("wrote", len(icons), "icons")


if __name__ == "__main__":
    args = sys.argv[1:]
    main(args[0], args[args.index("--preview") + 1] if "--preview" in args else None)
