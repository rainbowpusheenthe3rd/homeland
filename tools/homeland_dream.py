r"""Make the dream wreaths (21 Nov 2026): the minimap frames Shan'do's meditations borrow while they play.

    uv run --no-project --with pillow --with numpy --with scipy python tools/homeland_dream.py <art dir> [name ...]

<art dir> is the wreath pipeline's folder; each dream wreath was laid out, built in Blender and painted by MOSS in
homeland_r2/<Name>/ exactly as the race wreaths were (layouts.py, wreath_scene.py, moss_r2.py; run_dream.sh), and is
cut here by homeland_wreath.make into dream_<meditation id>.tga. Names map to Shan'do's meditation ids below. It
prints each one's fit (art width as a multiple of the map's); Homeland draws a dream wreath at your own frame's size.
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from homeland_wreath import make  # noqa: E402

DREAMS = {"Acorn": "acorn", "Ember": "ember"}   # pipeline folder -> Shan'do meditation id


def main(art, names):
    art = Path(art)
    print("dream\tsource\tfit_size\tinner_radius_frac")
    for name in names or list(DREAMS):
        d = art / "homeland_r2" / name
        rdir = d / "renditions" / "dream"
        size, frac = make(rdir / "moss.png", rdir, rdir / "layout.json", [DREAMS[name]], prefix="dream_")
        print(f"{DREAMS[name]}\t{(rdir / 'moss.png').relative_to(art).as_posix()}\t{size:.3f}\t{frac:.3f}")


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2:])
