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
    ("image-1af7d057.jpg", "Buding", "Sleepy", "布丁·犯困"),
    # 雪球（白兔）：空状态主力
    ("image-bf303ddd.jpg", "Xueqiu", "Blink", "雪球·眨眼"),
    ("image-37a40640.png", "Xueqiu", "Happy", "雪球·开心"),
    ("image-4dc4b665.jpg", "Xueqiu", "Sleepy", "雪球·犯困"),
    # 芝麻（仓鼠）：生词本
    ("image-8c4ca4ba.jpg", "Zhima", "Blink", "芝麻·眨眼"),
    ("image-c58fe7a8.png", "Zhima", "Happy", "芝麻·开心"),
    ("image-9735188c.png", "Zhima", "Sleepy", "芝麻·犯困"),
    # 棉花（垂耳兔）：新词空态
    ("image-400d8968.jpg", "Mianhua", "Blink", "棉花·眨眼"),
    ("image-433e0910.png", "Mianhua", "Happy", "棉花·开心"),
    ("image-41f65149.jpg", "Mianhua", "Sleepy", "棉花·犯困"),
    # 泡泡（水獭）：测试空态
    ("image-75c0154e.jpg", "Paopao", "Happy", "泡泡·开心"),
    ("image-b8681cb1.jpg", "Paopao", "Sleepy", "泡泡·犯困"),
    # 咕噜（小熊）：词库空态
    ("image-a96123ae.jpg", "Gulu", "Happy", "咕噜·开心"),
    ("image-444119b0.jpg", "Gulu", "Sleepy", "咕噜·犯困"),
    # 团子（柴犬）：连续打卡
    ("image-9bcdceaa.jpg", "Dango", "Happy", "团子·开心"),
    ("image-6a21d7a9.png", "Dango", "Sleepy", "团子·犯困"),
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