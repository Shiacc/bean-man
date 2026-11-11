"""把 AI 出的表情图裁成和主立绘同一套「取景」，避免眨眼/换表情时角色突然变大。

为什么要这一步：`ai_cutout.py` 只做「抠白底 + 裁到内容 + 补方」，
而 AI 出的图里角色占画布的比例和主立绘不一样。直接换图会出现「眨眼一下胖一圈」。

做法：
1. 抠白底（复用 ai_cutout 的 flood_white）；
2. 以主立绘（`<Name>.imageset/<name>@2x.png`，512）的 alpha 外接框为基准；
3. 把表情图缩放到「内容高度 = 主立绘内容高度」，底边对齐主立绘底边、水平居中；
4. 输出 512 单档 PNG 到 `<Name><Expr>.imageset/`，并写 Contents.json。

用法：
    python Scripts/ai_expression_frames.py --expr-dir Design/Animals/_ai/expr \
        --out BeanMan/Resources/Assets.xcassets/Animals [--only Awu]
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path

from PIL import Image

from ai_cutout import flood_white, trim

CANVAS = 512
# 和主立绘完全一样的取景：内容高度对齐，四周不留额外内边距
PAD_RATIO = 0.0


def content_bbox(img: Image.Image) -> tuple[int, int, int, int] | None:
    return img.split()[-1].getbbox()


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--expr-dir", default="Design/Animals/_ai/expr")
    ap.add_argument("--out", default="BeanMan/Resources/Assets.xcassets/Animals")
    ap.add_argument("--only", default="")
    args = ap.parse_args()

    expr_dir = Path(args.expr_dir)
    out_dir = Path(args.out)
    made = 0

    for src in sorted(expr_dir.glob("*.jpg")):
        stem = src.stem  # 例如 awu-happy
        if "-" not in stem:
            continue
        animal_part, expr_part = stem.split("-", 1)
        if args.only and animal_part.lower() != args.only.lower():
            continue

        # 找主立绘（文件名大小写不一定一致，按 imageset 目录名匹配）
        candidates = [p for p in out_dir.glob("*.imageset") if p.name.lower() == f"{animal_part.lower()}.imageset"]
        if not candidates:
            print("skip (no main imageset):", stem)
            continue
        main_set = candidates[0]
        main_name = main_set.name.replace(".imageset", "")
        main_png = main_set / f"{main_name.lower()}@2x.png"
        if not main_png.exists():
            print("skip (no @2x):", main_png)
            continue

        main_img = Image.open(main_png).convert("RGBA")
        main_box = content_bbox(main_img)
        if not main_box:
            print("skip (empty main):", main_png)
            continue
        main_h = main_box[3] - main_box[1]
        main_cx = (main_box[0] + main_box[2]) / 2

        art = trim(flood_white(Image.open(src)))
        box = content_bbox(art)
        if not box:
            print("skip (empty art):", src)
            continue
        art_w, art_h = box[2] - box[0], box[3] - box[1]
        art = art.crop(box)

        scale = main_h / art_h
        max_side = CANVAS * (1 - 2 * PAD_RATIO)
        if art_w * scale > max_side or art_h * scale > max_side:
            scale = min(max_side / art_w, max_side / art_h)
        new_size = (max(1, round(art_w * scale)), max(1, round(art_h * scale)))
        art = art.resize(new_size, Image.LANCZOS)

        canvas = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
        x = round(main_cx - new_size[0] / 2)
        y = round(main_box[3] - new_size[1])          # 底边对齐
        x = min(max(0, x), CANVAS - new_size[0])
        y = min(max(0, y), CANVAS - new_size[1])
        canvas.paste(art, (x, y), art)

        name = main_name + expr_part.capitalize()
        set_dir = out_dir / f"{name}.imageset"
        set_dir.mkdir(parents=True, exist_ok=True)
        fname = f"{name.lower()}.png"
        canvas.quantize(colors=96, method=Image.FASTOCTREE).save(set_dir / fname, optimize=True)
        (set_dir / "Contents.json").write_text(
            json.dumps(
                {
                    "images": [{"filename": fname, "idiom": "universal", "scale": "1x"}],
                    "info": {"author": "xcode", "version": 1},
                    "properties": {"template-rendering-intent": "original"},
                },
                indent=2,
                ensure_ascii=False,
            )
            + "\n",
            encoding="utf-8",
        )
        made += 1

    print("frames written:", made)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())