r"""Gallery sheet of the Skyborne minimap frames (20 Nov 2026): the shared Zephras Isle wreath, then the Horde and
Alliance wreaths it fades to, on the same dark ground as docs/map_frames.png, each captioned.

    uv run --no-project --with pillow python tools/homeland_sheet_skyborne.py

Writes docs/map_skyborne.png.
"""
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

HERE = Path(__file__).resolve().parent.parent
FRAMES = [("map_skyborne.tga", "Zephras Isle: every Skyborne"), ("map_skyborne_horde.tga", "Horde"),
          ("map_skyborne_alliance.tga", "Alliance")]
CELL, PAD, CAP = 400, 24, 44


def main():
    ref = Image.open(HERE / "docs" / "map_frames.png").convert("RGB")
    ground = ref.getpixel((4, 4))
    w = len(FRAMES) * (CELL + PAD) + PAD
    sheet = Image.new("RGB", (w, CELL + 2 * PAD + CAP), ground)
    draw = ImageDraw.Draw(sheet)
    try:
        font = ImageFont.truetype("segoeui.ttf", 22)
    except OSError:
        font = ImageFont.load_default()
    for i, (name, caption) in enumerate(FRAMES):
        art = Image.open(HERE / name).convert("RGBA").resize((CELL, CELL), Image.LANCZOS)
        x = PAD + i * (CELL + PAD)
        sheet.paste(art, (x, PAD), art)
        tw = draw.textlength(caption, font=font)
        draw.text((x + (CELL - tw) / 2, PAD + CELL + 10), caption, fill=(200, 190, 175), font=font)
    sheet.save(HERE / "docs" / "map_skyborne.png")


if __name__ == "__main__":
    main()
