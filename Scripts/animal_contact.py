"""拼一张 20 只小动物的大合照（5 x 4），用于目检风格一致性。

用法：
    python Scripts/animal_contact.py
产物：Design/Animals/contact-sheet-v1.png（每格 320，间距 24，底部留标签）
"""
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent.parent
ANIMALS = [
    ("01", "橘子", "01-juzi-orange-cat", "juzi"),
    ("02", "团子", "02-dango-shiba", "dango"),
    ("03", "棉花", "03-mianhua-rabbit", "mianhua"),
    ("04", "芝麻", "04-zhima-hamster", "zhima"),
    ("05", "竹竹", "05-zhuzhu-panda", "zhuzhu"),
    ("06", "豆芽", "06-douya-chick", "douya"),
    ("07", "慢慢", "07-manman-sloth", "manman"),
    ("08", "泡泡", "08-paopao-otter", "paopao"),
    ("09", "闪闪", "09-shanshan-firefly", "shanshan"),
    ("10", "布丁", "10-buding-corgi", "buding"),
    ("11", "呱呱", "11-guagua-frog", "guagua"),
    ("12", "刺刺", "12-cici-hedgehog", "cici"),
    ("13", "雪球", "13-xueqiu-rabbit", "xueqiu"),
    ("14", "啊呜", "14-awu-dino", "awu"),
    ("15", "啾啾", "15-jiujiu-sparrow", "jiujiu"),
    ("16", "卷卷", "16-juanjuan-sheep", "juanjuan"),
    ("17", "咔咔", "17-kaka-crab", "kaka"),
    ("18", "云朵", "18-yunduo-seal", "yunduo"),
    ("19", "咕噜", "19-gulu-bear", "gulu"),
    ("20", "小柚", "20-youzi-fox", "youzi"),
]

CELL = 320
GAP = 24
PAD = 40
COLS = 5
LABEL_H = 56


def font(size: int):
    for name in ("msyhbd.ttc", "msyh.ttc", "seguiemj.ttf", "DejaVuSans-Bold.ttf"):
        try:
            return ImageFont.truetype(name, size)
        except OSError:
            continue
    return ImageFont.load_default()


def main() -> int:
    rows = (len(ANIMALS) + COLS - 1) // COLS
    width = PAD * 2 + COLS * CELL + (COLS - 1) * GAP
    height = PAD * 2 + rows * (CELL + LABEL_H) + (rows - 1) * GAP + 60
    sheet = Image.new("RGB", (width, height), "#F7F5F1")
    draw = ImageDraw.Draw(sheet)
    f_title = font(30)
    f_label = font(20)
    draw.text((PAD, PAD - 8), "豆卡单词 · 20 只小动物 v1（立绘）", font=f_title, fill="#1C1B18")

    top = PAD + 52
    missing = []
    for i, (num, name, folder, slug) in enumerate(ANIMALS):
        col, row = i % COLS, i // COLS
        x = PAD + col * (CELL + GAP)
        y = top + row * (CELL + LABEL_H + GAP)
        src = ROOT / "Design" / "Animals" / folder / "render" / f"{slug}-master.png"
        if not src.exists():
            missing.append(str(src))
            draw.rectangle([x, y, x + CELL, y + CELL], outline="#D93A2B", width=3)
            continue
        img = Image.open(src).convert("RGBA")
        img.thumbnail((CELL, CELL), Image.LANCZOS)
        tile = Image.new("RGBA", (CELL, CELL), (0, 0, 0, 0))
        tile.paste(img, ((CELL - img.width) // 2, (CELL - img.height) // 2), img)
        sheet.paste(tile, (x, y), tile)
        draw.text((x + 4, y + CELL + 8), f"{num} {name}", font=f_label, fill="#6E6962")

    out = ROOT / "Design" / "Animals" / "contact-sheet-v1.png"
    sheet.save(out)
    print(f"[ok] {out} ({sheet.width}x{sheet.height})")
    if missing:
        for m in missing:
            print("[missing]", m)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())