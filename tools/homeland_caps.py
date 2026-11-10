r"""Make trial action-bar end caps from the race concept images: each race's homeland wreath in place of the
gryphon or wyvern.

  uv run --with pillow --with numpy python tools/homeland_caps.py <concept dir> [--preview <png>]

Reads concept_<Race>.png (768 px MOSS concepts, dark background) and writes cap_<race>_<side>.tga.
The left cap is the concept's bottom-left corner (where its plants root and climb), the right cap its bottom-right,
at the end caps' 154 x 95 aspect. The dark background is keyed out to alpha by its distance from the corner
colour, so only the plants show. Each TGA is 256 x 256 with the cap in its top 158 rows (the addon sets the
texture coordinates to match).
"""
import sys
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT
RACES = ["Human", "Dwarf", "Night_Elf", "Gnome", "Orc", "Undead", "Tauren", "Troll"]
W, H = 256, 158                      # 154 x 95 aspect
CROP_W = 0.46                        # fraction of the concept's width taken for one cap
INSET = {"Night_Elf": 0.12}       # step in from the outer and bottom edges, past the concept's printed border
TAPER = 0.40                         # the inner end fades over this fraction of the cap, so stems thin out
                                     # before the bar instead of running onto its buttons


def cap(img, side, inset=0.06):
    """Crop one bottom corner at the cap's aspect, keyed to RGBA."""
    n = img.shape[1]
    cw = int(n * CROP_W)
    ch = int(cw * H / W)
    m = int(n * inset)
    y1 = img.shape[0] - m
    crop = img[y1 - ch:y1, m:m + cw] if side == "left" else img[y1 - ch:y1, n - m - cw:n - m]
    bg = np.median(np.concatenate([img[:24, :24].reshape(-1, 3), img[:24, -24:].reshape(-1, 3)]), axis=0)
    dist = np.linalg.norm(crop - bg, axis=-1)
    alpha = np.clip((dist - 18) / 50, 0, 1)
    edge = np.ones_like(alpha)
    t = int(cw * TAPER)                          # inner end: a long smoothstep fade
    s = np.linspace(1, 0, t)
    s = s * s * (3 - 2 * s)
    if side == "left":
        edge[:, -t:] *= s
    else:
        edge[:, :t] *= s[::-1]
    o = 16                                       # outer, bottom and top: short fades so no edge is ruled
    ramp = np.linspace(0, 1, o)
    edge[:o, :] *= ramp[:, None]
    edge[-o:, :] *= ramp[::-1][:, None]
    if side == "left":
        edge[:, :o] *= ramp
    else:
        edge[:, -o:] *= ramp[::-1]
    rgba = np.dstack([crop / 255, alpha * edge])
    im = Image.fromarray((rgba * 255).astype("uint8"), "RGBA").resize((W, H), Image.LANCZOS)
    full = Image.new("RGBA", (256, 256), (0, 0, 0, 0))
    full.paste(im, (0, 0))
    return full


def write_tga(im, path):
    """32-bit uncompressed TGA, top-left origin, as the game reads it."""
    a = np.asarray(im)
    head = bytes([0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0]) + im.width.to_bytes(2, "little") + \
        im.height.to_bytes(2, "little") + bytes([32, 0x28])
    path.write_bytes(head + a[..., [2, 1, 0, 3]].tobytes())


def main(src, preview=None):
    OUT.mkdir(parents=True, exist_ok=True)
    tiles = []
    for race in RACES:
        img = np.asarray(Image.open(Path(src) / f"concept_{race}.png").convert("RGB")).astype(float)
        pair = []
        for side in ("left", "right"):
            im = cap(img, side, INSET.get(race, 0.06))
            write_tga(im, OUT / f"cap_{race.lower()}_{side}.tga")
            # "hug": the same cap mirrored, so its heavy corner sits against the bar and it trails off outwards
            hug = Image.new("RGBA", (256, 256), (0, 0, 0, 0))
            hug.paste(im.crop((0, 0, W, H)).transpose(Image.FLIP_LEFT_RIGHT), (0, 0))
            write_tga(hug, OUT / f"cap_{race.lower()}_{side}_hug.tga")
            pair.append(im.crop((0, 0, W, H)))
        tiles.append(pair)
        # the whole square, for round the minimap: keyed the same way, edges faded so nothing is ruled
        bg = np.median(np.concatenate([img[:24, :24].reshape(-1, 3), img[:24, -24:].reshape(-1, 3)]), axis=0)
        alpha = np.clip((np.linalg.norm(img - bg, axis=-1) - 18) / 50, 0, 1)
        n = img.shape[0]
        i = np.arange(n)
        e = np.minimum(np.minimum(i, i[::-1])[None, :], np.minimum(i, i[::-1])[:, None])   # distance to an edge
        alpha = alpha * np.clip(e / 12, 0, 1)
        sq = Image.fromarray((np.dstack([img / 255, alpha]) * 255).astype("uint8"), "RGBA").resize((512, 512),
                                                                                                   Image.LANCZOS)
        write_tga(sq, OUT / f"map_{race.lower()}.tga")
    if preview:   # each race: left cap, a stand-in bar, right cap, on a mid-grey like the game's HUD
        sheet = Image.new("RGBA", (2 * W + 300, len(tiles) * (H + 10)), (70, 70, 74, 255))
        for k, (l, r) in enumerate(tiles):
            y = k * (H + 10)
            bar = Image.new("RGBA", (300, 50), (30, 30, 34, 255))
            sheet.alpha_composite(bar, (W, y + H - 55))
            sheet.alpha_composite(l, (0, y))
            sheet.alpha_composite(r, (W + 300, y))
        sheet.save(preview)
    print("written to", OUT)


if __name__ == "__main__":
    a = sys.argv[1:]
    main(a[0], a[a.index("--preview") + 1] if "--preview" in a else None)
