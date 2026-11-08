"""把 AI 生图（纯白底 + 白贴纸边 + 淡投影）处理成 App 可用的透明 PNG。

只从「与画布边缘连通」的近白像素开始抠，避免把奶油白身体抠穿。

用法：
    python Scripts/ai_cutout.py <in.png> --name Zhuzhu --out <Assets.xcassets/Animals> [--display 竹竹]
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

WHITE_MIN = 185          # 亮度下限：白贴纸边、淡投影都在这之上
WHITE_SPREAD = 30        # 三通道最大差：只看「灰白」像素，奶油色身体（有色偏）排除
FEATHER = 0.5


def flood_white(img: Image.Image) -> Image.Image:
    """返回带 alpha 的 RGBA：与边框连通的近白区域（含白贴纸边、淡投影）变透明。"""
    rgb = img.convert("RGB")
    w, h = rgb.size
    px = rgb.load()

    near_white = Image.new("L", (w, h), 0)
    np_ = near_white.load()
    for y in range(h):
        for x in range(w):
            r, g, b = px[x, y]
            if min(r, g, b) >= WHITE_MIN and (max(r, g, b) - min(r, g, b)) <= WHITE_SPREAD:
                np_[x, y] = 255

    outer = near_white.copy()
    seeds = ((0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1),
             (w // 2, 0), (w // 2, h - 1), (0, h // 2), (w - 1, h // 2))
    for seed in seeds:
        if outer.load()[seed] == 255:
            ImageDraw.floodfill(outer, seed, 128)

    out = rgb.convert("RGBA")
    op = out.load()
    filled = outer.load()
    for y in range(h):
        for x in range(w):
            if filled[x, y] == 128:
                op[x, y] = (px[x, y][0], px[x, y][1], px[x, y][2], 0)

    if FEATHER:
        alpha = out.split()[-1].filter(ImageFilter.GaussianBlur(FEATHER))
        out.putalpha(alpha)
    return out


def trim(img: Image.Image, pad: int = 12) -> Image.Image:
    bbox = img.split()[-1].getbbox()
    if not bbox:
        return img
    l, t, r, b = bbox
    l, t = max(0, l - pad), max(0, t - pad)
    r, b = min(img.width, r + pad), min(img.height, b + pad)
    return img.crop((l, t, r, b))


def square(img: Image.Image) -> Image.Image:
    side = max(img.width, img.height)
    canvas = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    canvas.paste(img, ((side - img.width) // 2, (side - img.height) // 2), img)
    return canvas


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("src")
    ap.add_argument("--name", required=True)
    ap.add_argument("--display", default="")
    ap.add_argument("--out", default="BeanMan/Resources/Assets.xcassets/Animals")
    ap.add_argument("--sizes", default="256,512,768")
    args = ap.parse_args()

    src = Image.open(args.src)
    cut = trim(square(flood_white(src)))
    sizes = [int(s) for s in args.sizes.split(",")]

    set_dir = Path(args.out) / f"{args.name}.imageset"
    set_dir.mkdir(parents=True, exist_ok=True)
    files = []
    for i, size in enumerate(sizes):
        img = cut.resize((size, size), Image.LANCZOS)
        fname = f"{args.name.lower()}.png" if i == 0 else f"{args.name.lower()}@{i + 1}x.png"
        img.quantize(colors=96, method=Image.FASTOCTREE).save(set_dir / fname, optimize=True)
        files.append({"filename": fname, "idiom": "universal", "scale": f"{i + 1}x"})

    (set_dir / "Contents.json").write_text(
        json.dumps(
            {
                "images": files,
                "info": {"author": "xcode", "version": 1},
                "properties": {"template-rendering-intent": "original"},
            },
            indent=2,
            ensure_ascii=False,
        )
        + "\n",
        encoding="utf-8",
    )
    cut_dir = Path("Design/Animals/_ai")
    cut_dir.mkdir(parents=True, exist_ok=True)
    cut.save(cut_dir / f"{args.name.lower()}-cut.png")
    print("wrote", set_dir, [f["filename"] for f in files])
    return 0


if __name__ == "__main__":
    raise SystemExit(main())