"""把表情变体切成单档 512 的 imageset，并拼一张验收对照图。

约定：imageset 名 = <动物英文名><表情后缀>，例：JuziBlink、BudingHappy。
表情后缀与 Swift 里的 AnimalExpression 一致：Happy / Blink / Sleepy / Surprised。

用法：
    python Scripts/ai_expressions.py            # 处理 PENDING 里所有条目
    python Scripts/ai_expressions.py --sheet    # 只重拼对照图
"""

from __future__ import annotations

import argparse
import subprocess
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent.parent
SRC = Path(r"D:\deepseek-harness\resources\dsh-profiles\dsh-image-gen")
ASSETS = ROOT / "BeanMan/Resources/Assets.xcassets/Animals"
CUT_DIR = ROOT / "Design/Animals/_ai"
FONT = r"C:\Windows\Fonts\msyh.ttc"

# (源图, 动物英文名, 表情后缀, 中文名)
PENDING = [
    ("image-3ccc38e6.png", "Juzi", "Blink", "橘子·眨眼"),
    ("image-9c2b710a.jpg", "Juzi", "Happy", "橘子·开心"),
    ("image-3a82dc80.jpg", "Juzi", "Sleepy", "橘子·犯困"),
    ("image-5265e0c8.jpg", "Buding", "Blink", "布丁·眨眼"),
    ("image-e5d36157.png", "Buding", "Happy", "布丁·开心"),
]


def cut(src: Path, name: str, display: str) -> None:
    subprocess.run(
        [
            sys.executable,
            str(ROOT / "Scripts/ai_cutout.py"),
            str(src),
            "--name",
            name,
            "--display",
            display,
            "--sizes",
            "512",
        ],
        check=True,
        cwd=ROOT,
        stdout=subprocess.DEVNULL,
    )


def build_sheet() -> Path:
    items = [(CUT_DIR / f"{n.lower()}-cut.png", d) for _, n, _, d in PENDING if (CUT_DIR / f"{n.lower()}-cut.png").exists()]
    if not items:
        raise SystemExit("没有可拼的图")
    cell, pad, label_h = 300, 24, 44
    cols = min(5, len(items))
    rows = (len(items) + cols - 1) // cols
    w = cols * cell + (cols + 1) * pad
    h = rows * (cell + label_h) + (rows + 1) * pad
    sheet = Image.new("RGB", (w, h), "#F7F5F1")
    draw = ImageDraw.Draw(sheet)
    font = ImageFont.truetype(FONT, 18)
    for i, (path, label) in enumerate(items):
        img = Image.open(path).convert("RGBA")
        img.thumbnail((cell, cell), Image.LANCZOS)
        col, row = i % cols, i // cols
        x = pad + col * (cell + pad) + (cell - img.width) // 2
        y = pad + row * (cell + label_h + pad) + (cell - img.height) // 2
        tile = Image.new("RGBA", (cell, cell), (255, 255, 255, 255))
        tile.alpha_composite(img, ((cell - img.width) // 2, (cell - img.height) // 2))
        sheet.paste(tile.convert("RGB"), (pad + col * (cell + pad), pad + row * (cell + label_h + pad)))
        draw.text((pad + col * (cell + pad) + 8, pad + row * (cell + label_h + pad) + cell + 10), label, fill="#1C1B18", font=font)
    out = ROOT / "Design/Animals/_ai/expressions-sheet-v2.png"
    sheet.save(out)
    return out


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--sheet", action="store_true")
    args = ap.parse_args()
    if not args.sheet:
        for fname, name, suffix, display in PENDING:
            src = SRC / fname
            if not src.exists():
                print("skip(missing)", fname)
                continue
            cut(src, f"{name}{suffix}", f"{display}")
            print("cut", f"{name}{suffix}")
    print("sheet:", build_sheet())
    return 0


if __name__ == "__main__":
    raise SystemExit(main())