r"""Gallery sheet of the round wreath minimap frames (20 Nov 2026): the eight races and the Skyborne, each with a
dark disc where the minimap sits at its default size (WREATH_FIT in Homeland.lua), on the same ground as
docs/map_frames.png.

    uv run --no-project --with pillow python tools/homeland_sheet_wreaths.py

Writes docs/map_wreaths.png.
"""
import re
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

HERE = Path(__file__).resolve().parent.parent
NAMES = [("human", "Human"), ("dwarf", "Dwarf"), ("night_elf", "Night elf"), ("gnome", "Gnome"), ("orc", "Orc"),
         ("undead", "Undead"), ("tauren", "Tauren"), ("troll", "Troll"), ("skyborne", "Skyborne")]
CELL, PAD, CAP, COLS = 300, 18, 34, 5
MAP = (24, 30, 26)                                  # the minimap stand-in


def main():
    lua = (HERE / "Homeland.lua").read_text(encoding="utf-8")
    fit = {k: float(v) for k, v in re.findall(r"(\w+) = ([\d.]+)", lua[lua.index("local WREATH_FIT"):].split("}")[0])}
    ground = Image.open(HERE / "docs" / "map_frames.png").convert("RGB").getpixel((4, 4))
    rows = (len(NAMES) + COLS - 1) // COLS
    sheet = Image.new("RGBA", (COLS * (CELL + PAD) + PAD, rows * (CELL + CAP + PAD) + PAD), ground + (255,))
    draw = ImageDraw.Draw(sheet)
    try:
        font = ImageFont.truetype("segoeui.ttf", 20)
    except OSError:
        font = ImageFont.load_default()
    for k, (name, label) in enumerate(NAMES):
        x = PAD + (k % COLS) * (CELL + PAD)
        y = PAD + (k // COLS) * (CELL + CAP + PAD)
        r = CELL / fit[name] / 2
        draw.ellipse((x + CELL / 2 - r, y + CELL / 2 - r, x + CELL / 2 + r, y + CELL / 2 + r), fill=MAP + (255,))
        art = Image.open(HERE / f"wreath_{name}.tga").convert("RGBA").resize((CELL, CELL), Image.LANCZOS)
        sheet.alpha_composite(art, (x, y))
        tw = draw.textlength(label, font=font)
        draw.text((x + (CELL - tw) / 2, y + CELL + 6), label, fill=(200, 190, 175), font=font)
    sheet.convert("RGB").save(HERE / "docs" / "map_wreaths.png")


if __name__ == "__main__":
    main()
