r"""Make the round wreath minimap frames (20 Nov 2026) from each race's latest round-2 painting.

    uv run --no-project --with pillow --with numpy --with scipy python tools/homeland_wreath.py <art dir>

<art dir> is the wreath pipeline's folder (homeland_r2/<Race>/... and skyborne_scratch/out/<layout>/). For each race
the newest painting (moss.png) under its renditions and live output is used, with the Blender maps of the same
rendition beside it:
  - alpha: the round-2 paintings have a painted, textured ground, so a colour key alone keeps the texture. The plants
    are taken from Blender's flat colour map (every pixel that is not the ground), less the thin square frame
    (its inset and width from layout.json), grown 3 px for the painter's soft edges and feathered; within that the
    painting is keyed against its own ground colour (homeland_caps.key), so painted gaps stay clear;
  - colour: un-mixed and lifted as for the square frames (homeland_caps.key);
  - edges faded over 12 px, then 512 x 512, written as wreath_<race>.tga. Skyborne has one painting, used for the
    shared, Horde and Alliance names.
It prints each race's source and its fit: the art's width as a multiple of the minimap's width that puts the
wreath's inner edge (10th percentile over angles of the first opaque radius) just outside the map.
"""
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage

sys.path.insert(0, str(Path(__file__).resolve().parent))
from homeland_caps import key, write_tga  # noqa: E402

ROOT = Path(__file__).resolve().parents[1]
RACES = ["Human", "Dwarf", "Night_Elf", "Gnome", "Orc", "Undead", "Tauren", "Troll"]
SKY = ("ring", ["skyborne", "skyborne_horde", "skyborne_alliance"])     # the latest Skyborne layout
GROUND_TOL = 12                       # colour-map distance from the ground below which a pixel is ground
GROW, FEATHER, EDGE = 3, 1.5, 12


def newest(paths):
    paths = [p for p in paths if p.exists()]
    return max(paths, key=lambda p: p.stat().st_mtime) if paths else None


def plant_alpha(paint, cmap, layout):
    """Soft 0-1 plant mask: the colour map's non-ground pixels less the frame, grown and feathered, times the key."""
    gcol = np.median(np.concatenate([cmap[:24, :24].reshape(-1, 3), cmap[:24, -24:].reshape(-1, 3)]), axis=0)
    geo = np.abs(cmap - gcol).sum(-1) > GROUND_TOL
    n = cmap.shape[0]
    i = np.arange(n)
    edge = np.minimum(np.minimum(i, i[::-1])[None, :], np.minimum(i, i[::-1])[:, None])
    for s in layout["shapes"]:
        if "inset" in s:                                    # the square frame: a band round the edge
            geo &= ~(np.abs(edge - s["inset"]) <= s["width"] + 8)
    geo &= edge >= 4                                       # some colour maps carry a 1 px border (Orc)
    geo = ndimage.binary_dilation(geo, iterations=GROW)
    soft = np.clip(ndimage.gaussian_filter(geo.astype(float), FEATHER) * 1.5, 0, 1)
    bg = np.median(paint[~geo], axis=0)                     # the painting's own ground
    rgb, ka = key(paint, bg)
    return rgb, soft * ka, edge


def fit(alpha):
    """Art width / map width that puts the inner edge of the wreath just outside a round map."""
    n = alpha.shape[0]
    c = (n - 1) / 2
    r = np.arange(int(n * 0.5))
    firsts = []
    for th in np.linspace(0, 2 * np.pi, 360, endpoint=False):
        y = np.clip(np.round(c + r * np.sin(th)).astype(int), 0, n - 1)
        x = np.clip(np.round(c + r * np.cos(th)).astype(int), 0, n - 1)
        hit = np.flatnonzero(alpha[y, x] > 0.5)
        firsts.append(hit[0] if hit.size else r[-1])
    r_in = np.percentile(firsts, 10)
    return n / (2 * r_in), r_in / n


def make(paint_path, rdir, layout_path, names):
    paint = np.asarray(Image.open(paint_path).convert("RGB")).astype(float)
    cmap = np.asarray(Image.open(rdir / "colour.png").convert("RGB")).astype(float)
    rgb, alpha, edge = plant_alpha(paint, cmap, json.loads(Path(layout_path).read_text()))
    alpha = alpha * np.clip(edge / EDGE, 0, 1)
    im = Image.fromarray((np.dstack([rgb / 255, alpha]) * 255).astype("uint8"), "RGBA").resize((512, 512),
                                                                                               Image.LANCZOS)
    for nm in names:
        write_tga(im, ROOT / f"wreath_{nm}.tga")
    size, frac = fit(np.asarray(im)[..., 3] / 255)
    return size, frac


def main(art):
    art = Path(art)
    rows = []
    for race in RACES:
        d = art / "homeland_r2" / race
        p = newest(list((d / "renditions").glob("*/moss.png")) + [d / "out" / "moss.png"])
        rdir = p.parent if p.parent.name != "out" else d / "renditions" / "r2b"
        if p.parent.name == "out" and not (rdir / "colour.png").exists():
            rdir = d / "out"
        size, frac = make(p, rdir, rdir / "layout.json", [race.lower()])
        rows.append((race, p.relative_to(art).as_posix(), size, frac))
    sd = art / "skyborne_scratch"
    p = sd / "out" / SKY[0] / "moss.png"
    size, frac = make(p, p.parent, sd / f"layout_{SKY[0]}.json", SKY[1])
    rows.append(("Skyborne", p.relative_to(art).as_posix(), size, frac))
    print("race\tsource\tfit_size\tinner_radius_frac")
    for r in rows:
        print(f"{r[0]}\t{r[1]}\t{r[2]:.3f}\t{r[3]:.3f}")


if __name__ == "__main__":
    main(sys.argv[1])
