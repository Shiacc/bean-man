"""批量：AI 生图 → 抠白底 → 导出 imageset → 拼对照图。

用法：
    python Scripts/ai_batch.py            # 处理 MAPPING 里列出的全部条目
    python Scripts/ai_batch.py --sheet    # 只重拼对照图
"""

from __future__ import annotations

import subprocess
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent.parent
GEN = Path(r"D:\deepseek-harness\resources\dsh-profiles\dsh-image-gen")
OUT_ANIMALS = ROOT / "BeanMan/Resources/Assets.xcassets/Animals"
CUT_DIR = ROOT / "Design/Animals/_ai"

# (图片文件名, imageset 名, 中文名)
MAPPING = [
    ("image-394d33e1.jpg", "Zhuzhu", "竹竹"),
    ("image-dfa733d1.jpg", "Juzi", "橘子"),
    ("image-ba63a594.png", "Dango", "团子"),
    ("image-084c25aa.jpg", "Mianhua", "棉花"),
    ("image-0ea31c5f.jpg", "Zhima", "芝麻"),
    ("image-19505928.jpg", "Douya", "豆芽"),
    ("image-7d759d8c.jpg", "Manman", "慢慢"),
    ("image-7ed10608.png", "Paopao", "泡泡"),
    ("image-7ebf6e6d.png", "Shanshan", "闪闪"),
    ("image-f735f373.jpg", "Buding", "布丁"),
    ("image-ac9bc6e5.jpg", "Guagua", "呱呱"),
    ("image-39dac86e.jpg", "Cici", "刺刺"),
    ("image-a4a73e13.jpg", "Xueqiu", "雪球"),
    ("image-7b91ba73.jpg", "Awu", "啊呜"),
    ("image-0d43a384.jpg", "Jiujiu", "啾啾"),
    ("image-5d8027bb.jpg", "Juanjuan", "卷卷"),
    ("image-667943a3.jpg", "Kaka", "咔咔"),
    ("image-109ac07e.jpg", "Yunduo", "云朵"),
    ("image-5db3b124.jpg", "Gulu", "咕噜"),
    ("image-17ef96d4.jpg", "Youzi", "小柚"),
]


def run_cutout(src: Path, name: str) -> None:
    subprocess.run(
        [sys.executable, str(ROOT / "Scripts/ai_cutout.py"), str(src), "--name", name, "--out", str(OUT_ANIMALS)],
        check=True,
    )


def sheet() -> Path:
    items = [(n, CUT_DIR / f"{n.lower()}-cut.png", d) for _, n, d in MAPPING if (CUT_DIR / f"{n.lower()}-cut.png").exists()]
    cell = 360
    pad = 24
    cols = 3
    rows = (len(items) + cols - 1) // cols
    W = cols * cell + (cols + 1) * pad
    H = rows * (cell + 40) + (rows + 1) * pad
    canvas = Image.new("RGB", (W, H), "#F7F5F1")
    draw = ImageDraw.Draw(canvas)
    try:
        font = ImageFont.truetype(r"C:\Windows\Fonts\msyh.ttc", 20)
    except OSError:
        font = ImageFont.load_default()

    for i, (name, path, cn) in enumerate(items):
        r, c = divmod(i, cols)
        x = pad + c * (cell + pad)
        y = pad + r * (cell + 40 + pad)
        tile = Image.new("RGB", (cell, cell), "#FFFFFF")
        img = Image.open(path).convert("RGBA")
        img.thumbnail((cell - 24, cell - 24), Image.LANCZOS)
        tile.paste(img, ((cell - img.width) // 2, (cell - img.height) // 2), img)
        canvas.paste(tile, (x, y))
        draw.text((x + 6, y + cell + 8), f"{cn} · {name}", fill="#3A2A22", font=font)

    out = ROOT / "Design/Animals/_ai/ai-style-sheet.png"
    canvas.save(out)
    return out


def main() -> int:
    if "--sheet" not in sys.argv:
        for fname, name, cn in MAPPING:
            src = GEN / fname
            if not src.exists():
                print("missing", src)
                continue
            run_cutout(src, name)
            print("cut", cn, name)
    print("sheet:", sheet())
    return 0


if __name__ == "__main__":
    raise SystemExit(main())