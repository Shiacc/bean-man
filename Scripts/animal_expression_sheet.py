# -*- coding: utf-8 -*-
"""把橘子 / 布丁的五种表情拼成一张对照图，方便一眼看出风格是否统一。"""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]

ROWS = [
    ("橘子", "01-juzi-orange-cat", [
        ("常态", "juzi-master.png"),
        ("眨眼", "juzi-blink.png"),
        ("开心", "juzi-happy.png"),
        ("犯困", "juzisleepy-master.png"),
        ("惊讶", "juzisurprised-master.png"),
    ]),
    ("布丁", "10-buding-corgi", [
        ("常态", "buding-master.png"),
        ("眨眼", "budingblink-master.png"),
        ("开心", "budinghappy-master.png"),
        ("犯困", "budingsleepy-master.png"),
        ("惊讶", "budingsurprised-master.png"),
    ]),
]

CELL = 320
LABEL = 34
PAD = 12
BG = (247, 245, 241, 255)


def main() -> None:
    cols = max(len(r[2]) for r in ROWS)
    w = PAD + cols * (CELL + PAD)
    h = PAD + len(ROWS) * (CELL + LABEL + PAD)
    sheet = Image.new("RGBA", (w, h), BG)
    draw = ImageDraw.Draw(sheet)
    try:
        font = ImageFont.truetype(r"C:\Windows\Fonts\msyh.ttc", 18)
    except OSError:
        font = ImageFont.load_default()

    for ri, (name, folder, items) in enumerate(ROWS):
        for ci, (label, fname) in enumerate(items):
            path = ROOT / "Design" / "Animals" / folder / "render" / fname
            if not path.exists():
                raise SystemExit(f"missing {path}")
            img = Image.open(path).convert("RGBA")
            img.thumbnail((CELL, CELL), Image.LANCZOS)
            x = PAD + ci * (CELL + PAD)
            y = PAD + ri * (CELL + LABEL + PAD)
            sheet.alpha_composite(img, (x + (CELL - img.width) // 2, y))
            draw.text((x + 6, y + CELL + 8), f"{name} · {label}", fill=(60, 55, 48, 255), font=font)

    out = ROOT / "Design" / "Animals" / "expressions-v1.png"
    sheet.convert("RGB").save(out, "PNG")
    print("wrote", out, sheet.size)


if __name__ == "__main__":
    main()