"""检查抠图边缘：把每只动物贴在品牌橙 / 深色 / 米色三种底上，看有没有白边。

白底上检查会骗人 —— 白边和背景同色看不出来，必须换有色底。

用法：python Scripts/ai_check_edges.py
"""

from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent.parent
CUT = ROOT / "Design/Animals/_ai"

NAMES = [
    ("Zhuzhu", "竹竹"), ("Juzi", "橘子"), ("Dango", "团子"),
    ("Mianhua", "棉花"), ("Zhima", "芝麻"), ("Douya", "豆芽"),
    ("Manman", "慢慢"), ("Paopao", "泡泡"), ("Shanshan", "闪闪"),
    ("Buding", "布丁"), ("Guagua", "呱呱"), ("Cici", "刺刺"),
    ("Xueqiu", "雪球"), ("Awu", "啊呜"), ("Jiujiu", "啾啾"),
    ("Juanjuan", "卷卷"), ("Kaka", "咔咔"), ("Yunduo", "云朵"),
    ("Gulu", "咕噜"), ("Youzi", "小柚"),
]

BACKS = [("#E4703A", 150), ("#1C1B18", 88), ("#FFF1E8", 88)]
COLS = 5
PAD = 14
LABEL = 22


def main() -> int:
    tiles = []
    for name, cn in NAMES:
        p = CUT / f"{name.lower()}-cut.png"
        if p.exists():
            tiles.append((name, cn, Image.open(p).convert("RGBA")))
    if not tiles:
        print("no cutouts")
        return 1

    cell_w = max(s for _, s in BACKS) + PAD * 2
    cell_h = sum(s for _, s in BACKS) + PAD * (len(BACKS) + 1) + LABEL
    rows = (len(tiles) + COLS - 1) // COLS

    canvas = Image.new("RGB", (COLS * cell_w, rows * cell_h + 16), "#FFFFFF")
    draw = ImageDraw.Draw(canvas)
    try:
        font = ImageFont.truetype(r"C:\Windows\Fonts\msyh.ttc", 15)
    except OSError:
        font = ImageFont.load_default()

    for idx, (name, cn, img) in enumerate(tiles):
        cx = (idx % COLS) * cell_w
        cy = (idx // COLS) * cell_h
        y = cy + PAD
        for color, size in BACKS:
            board = Image.new("RGBA", (cell_w - PAD * 2, size), color)
            im = img.copy()
            im.thumbnail((size - 10, size - 10), Image.LANCZOS)
            board.alpha_composite(im, ((board.width - im.width) // 2, (size - im.height) // 2))
            canvas.paste(board.convert("RGB"), (cx + PAD, y))
            y += size + PAD
        draw.text((cx + PAD, y - 4), f"{cn} {name}", fill="#6E6962", font=font)

    out = CUT / "edge-check.png"
    canvas.save(out)
    print(out, canvas.size, f"{len(tiles)} animals")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())