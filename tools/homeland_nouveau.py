r"""Homeland's art nouveau minimap frame: thin line art that follows the round map, one per race.

  uv run --no-project --with pillow --with numpy python tools/homeland_nouveau.py [--preview <png>]

Writes addon/Homeland/nouveau_<race>.tga (512 x 512). The addon sizes the texture to 1.5 x the minimap's width,
so the map's ring sits at radius 512 / 1.5 / 2 = 171 px.

Grown, not placed: two stems root at the bottom and follow the ring up each side. Each stem's curvature is the
ring's until three quarters of its length, then falls away with the square of the distance past that point (a
clothoid), so the tip whips outward into a tightening curl, the way a tendril does. Leaves sit at golden-ratio
spacing along the stem, closer together towards the tip, alternating sides, and shrink as the stem thins. One
stylised flower opens where the curl begins. The top of the ring is left bare for the zone text and the
minimap's buttons. Everything is drawn twice: a soft dark shadow, then the line in the race's colours, so it
reads on snow as well as on night grass.
"""
import math
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "addon" / "Homeland"
N, SS = 512, 4
C = N / 2
FIT = 1.7                       # the texture is FIT x the minimap's width (the addon sizes it)
RING = N / FIT / 2 + 20         # clear of the map's own border (about 13 px of texture)
PHI = (1 + 5 ** 0.5) / 2

# race -> (line, flower, flower centre), from each homeland's flora
PALETTE = {
    "night_elf": ((196, 186, 226), (240, 236, 255), (170, 150, 230)),   # moonflower, silver-lavender
    "human": ((206, 186, 120), (244, 196, 206), (236, 200, 90)),         # dog rose, wheat gold
    "dwarf": ((170, 188, 196), (196, 136, 206), (240, 220, 160)),        # heather, frost
    "gnome": ((212, 142, 82), (124, 172, 240), (240, 230, 200)),         # copper, blue mushroom
    "orc": ((196, 134, 92), (244, 130, 70), (250, 210, 110)),            # thorn, cactus flower
    "undead": ((160, 188, 140), (156, 116, 186), (220, 230, 170)),       # deathcap, nightshade
    "tauren": ((212, 182, 122), (244, 212, 96), (190, 120, 60)),         # prairie grass, wildflower
    "troll": ((120, 192, 162), (232, 112, 200), (250, 230, 150)),        # palm, orchid
}


def stem(side, length=2.88 * RING, curl_from=0.74, curl=5.6e-6):
    """Points (x, y) and the heading at each, from the bottom of the ring round one side and into a curl."""
    k0 = 1 / RING
    s1 = length * curl_from
    x, y, h = C, C + RING, 0.0                      # bottom of the ring, heading right (screen y points down)
    pts = []
    for i in range(int(length)):
        k = k0 - (curl * (i - s1) ** 2 if i > s1 else 0.0)
        h -= k                                        # turning up and round the ring; negative k turns outward
        x += math.cos(h)
        y += math.sin(h)
        pts.append((x, y, h))
    if side == "left":
        pts = [(2 * C - px, py, math.pi - ph) for px, py, ph in pts]
    return pts


def taper(d, pts, w0, w1, col):
    n = len(pts)
    for i, (x, y, _) in enumerate(pts):
        r = (w0 + (w1 - w0) * i / n) / 2
        d.ellipse(((x - r) * SS, (y - r) * SS, (x + r) * SS, (y + r) * SS), fill=col)


def leaf(d, x, y, ang, length, width, col, outline=None):
    pts = []
    for i in range(25):
        u = i / 24
        pts.append((u * length, width * math.sin(math.pi * u) ** 0.9))
    pts += [(u, -v) for u, v in reversed(pts)]
    ca, sa = math.cos(ang), math.sin(ang)
    poly = [((x + u * ca - v * sa) * SS, (y + u * sa + v * ca) * SS) for u, v in pts]
    d.polygon(poly, fill=col, outline=outline)


def flower(d, x, y, r, col, centre, ang0, line):
    for k in range(5):
        a = ang0 + k * 2 * math.pi / 5
        leaf(d, x, y, a, r, r * 0.42, col, line)
    d.ellipse(((x - r * 0.22) * SS, (y - r * 0.22) * SS, (x + r * 0.22) * SS, (y + r * 0.22) * SS), fill=centre)


def draw(d, race_cols, shadow=False):
    line, petal, centre = race_cols
    dark = (16, 12, 20, 255)
    lc = dark if shadow else line + (235,)
    grow = 3.0 if shadow else 0.0                    # the shadow is a touch wider
    for side in ("left", "right"):
        pts = stem(side)
        n = len(pts)
        gap = int(n * 0.11)                            # the bottom is left open, a cartouche for the coordinates
        taper(d, pts[gap:], 9.0 + grow, 2.6 + grow, lc)
        # a shorter tendril branching outward at the golden section of the stem, curling the same way
        bx, by, bh = pts[int(n / PHI ** 2)]
        sgn = 1 if side == "right" else -1
        h, x, y = bh + sgn * 0.0, bx, by
        tend = []
        for i in range(120):
            k = (1 / RING) * 0.4 - 1.1e-5 * i * i       # bends away from the map, then curls tight
            h -= sgn * k
            x += math.cos(h)
            y += math.sin(h)
            tend.append((x, y, h))
        taper(d, tend, 6.0 + grow, 1.8 + grow, lc)
        # a bud where the tendril's curl closes
        tx, ty, th = tend[-1]
        if shadow:
            d.ellipse(((tx - 15) * SS, (ty - 15) * SS, (tx + 15) * SS, (ty + 15) * SS), fill=dark)
        else:
            leaf(d, tx, ty, th - sgn * 1.2, 22, 8, petal + (230,), line + (255,))
            leaf(d, tx, ty, th - sgn * 0.6, 18, 6, petal + (200,), line + (255,))
        # leaves at golden-ratio spacing, denser towards the tip, alternating sides, shrinking as the stem thins
        # leaves only on the outer side (never over the map), alternating a wide and a narrow angle
        for j in range(1, 9):
            s = int(n * (1 - PHI ** (-j * 0.55)))
            if s >= n * 0.74:
                break
            if s < gap:
                continue
            x, y, hh = pts[s]
            spread = 0.95 if j % 2 else 0.55
            ang = max((hh + spread, hh - spread),
                      key=lambda a: (x + math.cos(a) - C) ** 2 + (y + math.sin(a) - C) ** 2)
            size = 34 * (1 - s / n * 0.55)
            leaf(d, x, y, ang, size + grow, size * 0.32 + grow / 2, (dark if shadow else line + (150,)),
                 None if shadow else line + (235,))
        # the flower, where the curl begins, set outward from the map's centre
        x, y, hh = pts[int(n * 0.74)]
        r0 = math.hypot(x - C, y - C)
        fx, fy = x + (x - C) / r0 * 16, y + (y - C) / r0 * 16
        if shadow:
            d.ellipse(((fx - 26) * SS, (fy - 26) * SS, (fx + 26) * SS, (fy + 26) * SS), fill=dark)
        else:
            flower(d, fx, fy, 23, petal + (225,), centre + (255,), hh, line + (255,))
    # a fine second line outside the stems, round the lower three quarters, so it reads as one frame
    arc = [(C + (RING + 16) * math.cos(a), C + (RING + 16) * math.sin(a), 0.0)
           for a in np.linspace(math.radians(-25), math.radians(205), 900)
           if not math.radians(66) < a < math.radians(114)]                 # open under the map, like the stems
    taper(d, arc, 2.0 + grow, 2.0 + grow, dark if shadow else line + (170,))


def frame(race):
    cols = PALETTE[race]
    sh = Image.new("RGBA", (N * SS, N * SS), (0, 0, 0, 0))
    draw(ImageDraw.Draw(sh), cols, shadow=True)
    sh = sh.resize((N, N), Image.LANCZOS).filter(ImageFilter.GaussianBlur(1.6))
    a = np.asarray(sh).astype(float)
    a[..., 3] *= 0.55
    sh = Image.fromarray(a.astype("uint8"), "RGBA")
    art = Image.new("RGBA", (N * SS, N * SS), (0, 0, 0, 0))
    draw(ImageDraw.Draw(art), cols)
    art = art.resize((N, N), Image.LANCZOS)
    sh.alpha_composite(art)
    return sh


def write_tga(im, path):
    a = np.asarray(im)
    head = bytes([0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0]) + im.width.to_bytes(2, "little") + \
        im.height.to_bytes(2, "little") + bytes([32, 0x28])
    path.write_bytes(head + a[..., [2, 1, 0, 3]].tobytes())


def main(preview=None):
    tiles = []
    for race in PALETTE:
        im = frame(race)
        write_tga(im, OUT / f"nouveau_{race}.tga")
        tiles.append(im)
    if preview:   # each race over a stand-in minimap on night grass, and one on bright snow
        sheet = Image.new("RGBA", (4 * 300, 3 * 300), (40, 52, 40, 255))
        for k, im in enumerate(tiles + [tiles[0]]):
            bg = Image.new("RGBA", (N, N), (226, 230, 236, 255) if k == 8 else (44, 58, 44, 255))
            d = ImageDraw.Draw(bg)
            r = N / FIT / 2
            d.ellipse((C - r, C - r, C + r, C + r), fill=(28, 40, 30, 255), outline=(150, 120, 70, 255), width=5)
            bg.alpha_composite(im)
            sheet.alpha_composite(bg.resize((300, 300), Image.LANCZOS), ((k % 4) * 300, (k // 4) * 300))
        sheet.save(preview)
    print("written to", OUT)


if __name__ == "__main__":
    a = sys.argv[1:]
    main(a[a.index("--preview") + 1] if "--preview" in a else None)
