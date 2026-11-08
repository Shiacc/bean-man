#!/usr/bin/env python3
"""把 AI 生成的场景插画接进 App：不做抠图（场景要保留米色底），只导出图集。

用法：
    python Scripts/ai_scenes.py            # 全量：导出图集 + 拼对照图
    python Scripts/ai_scenes.py --sheet    # 只重拼对照图

每个场景导出成 `BeanMan/Resources/Assets.xcassets/Illustrations/<Name>.imageset/`，
1024×1024 单档（`idiom: universal`），App 里按容器宽度缩放即可。
"""

from __future__ import annotations

import argparse
import io
import json
import os
import sys

from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = r"D:\deepseek-harness\resources\dsh-profiles\dsh-image-gen"
ASSETS = os.path.join(ROOT, "BeanMan", "Resources", "Assets.xcassets")
OUT = os.path.join(ASSETS, "Illustrations")
SHEET = os.path.join(ROOT, "Design", "Animals", "_ai", "scenes-sheet-v1.png")

# (源图, 场景英文名, 中文标签, 用在哪)
SCENES = [
    ("image-5fe0c62c.jpg", "SceneOnboardingWelcome", "引导·欢迎", "首次引导第 1 步"),
    ("image-cadca615.jpg", "SceneOnboardingPlan", "引导·计划", "首次引导第 2 步（每日新词）"),
    ("image-b480d926.jpg", "SceneOnboardingReminder", "引导·提醒", "首次引导第 3 步（提醒时间）"),
    ("image-ed0f4b43.jpg", "SceneOnboardingDone", "引导·完成", "首次引导第 4 步"),
    ("image-881d73ca.jpg", "SceneEmptyToday", "空态·今日", "今日没有要背的词"),
    ("image-336cedff.jpg", "SceneEmptyWrongBook", "空态·错词本", "错词本为空"),
    ("image-d753716d.jpg", "SceneEmptyFavorites", "空态·生词本", "生词本为空"),
    ("image-eb900b3c.jpg", "SceneEmptyDeck", "空态·词库", "还没有自建词库"),
    ("image-f2ccce9b.jpg", "SceneEmptyQuiz", "空态·测试", "学够 4 个词才能测"),
    ("image-697c9ec8.png", "SceneAchievement", "成就·解锁", "成就达成庆祝"),
    ("image-57d4511e.jpg", "SceneStreak", "统计·打卡", "连续打卡展示"),
    ("image-3a7cad3d.png", "SceneInsight", "小豆·分析", "洞察推荐页头图"),
    ("image-61dfa7f9.jpg", "SceneComeback", "补签·回来", "中断后回来学习"),
    ("image-a3d9325f.jpg", "SceneStudy", "学习·陪伴", "学习会话完成页"),
    ("image-b3011f2a.jpg", "SceneReview", "复习·清单", "到期复习入口"),
    ("image-165949a7.jpg", "SceneNight", "夜间·复习", "夜间提醒/深色场景"),
]

FONT_CANDIDATES = [
    r"C:\Windows\Fonts\msyh.ttc",
    r"C:\Windows\Fonts\msyhbd.ttc",
    "/System/Library/Fonts/PingFang.ttc",
    "/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc",
]


def font(size: int):
    for path in FONT_CANDIDATES:
        if os.path.exists(path):
            try:
                return ImageFont.truetype(path, size)
            except OSError:
                continue
    return ImageFont.load_default()


def export(src_name: str, asset: str, colors: int = 0) -> str:
    src = os.path.join(SRC, src_name)
    if not os.path.exists(src):
        sys.exit(f"找不到源图：{src}")
    img = Image.open(src).convert("RGB")
    if img.size != (1024, 1024):
        img = img.resize((1024, 1024), Image.LANCZOS)
    if colors:
        # 场景插画是平涂风格，128 色量化几乎无损，体积能降到原来的 1/7
        img = img.quantize(colors=colors, method=Image.FASTOCTREE, dither=Image.NONE)

    dest = os.path.join(OUT, f"{asset}.imageset")
    os.makedirs(dest, exist_ok=True)
    buf = io.BytesIO()
    img.save(buf, "PNG", optimize=True)
    with open(os.path.join(dest, "scene.png"), "wb") as fh:
        fh.write(buf.getvalue())

    contents = {
        "images": [
            {"filename": "scene.png", "idiom": "universal", "scale": "1x"},
            {"idiom": "universal", "scale": "2x"},
            {"idiom": "universal", "scale": "3x"},
        ],
        "info": {"author": "xcode", "version": 1},
        "properties": {"template-rendering-intent": "original"},
    }
    with open(os.path.join(dest, "Contents.json"), "w", encoding="utf-8") as fh:
        json.dump(contents, fh, ensure_ascii=False, indent=2)
    return dest


def write_root_contents() -> None:
    os.makedirs(OUT, exist_ok=True)
    payload = {"info": {"author": "xcode", "version": 1}}
    with open(os.path.join(OUT, "Contents.json"), "w", encoding="utf-8") as fh:
        json.dump(payload, fh, ensure_ascii=False, indent=2)


def build_sheet() -> None:
    cols = 4
    cell_w, cell_h = 340, 390
    rows = (len(SCENES) + cols - 1) // cols
    sheet = Image.new("RGB", (cols * cell_w + 40, rows * cell_h + 40), (247, 245, 241))
    draw = ImageDraw.Draw(sheet)
    title_font = font(20)
    label_font = font(17)
    small_font = font(13)

    for index, (src_name, asset, label, place) in enumerate(SCENES):
        img = Image.open(os.path.join(SRC, src_name)).convert("RGB")
        img.thumbnail((cell_w - 20, cell_w - 20), Image.LANCZOS)
        col, row = index % cols, index // cols
        x = 20 + col * cell_w
        y = 20 + row * cell_h
        sheet.paste(img, (x + 10, y + 10))
        draw.text((x + 10, y + cell_w + 6), label, fill=(28, 27, 24), font=label_font)
        draw.text((x + 10, y + cell_w + 30), place, fill=(110, 105, 98), font=small_font)

    os.makedirs(os.path.dirname(SHEET), exist_ok=True)
    sheet.save(SHEET, "PNG", optimize=True)
    print("sheet:", SHEET)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--sheet", action="store_true", help="只重拼对照图")
    parser.add_argument("--colors", type=int, default=128,
                        help="量化色数；0 = 不量化（默认 128 色，约 118KB/张）")
    args = parser.parse_args()

    if not args.sheet:
        write_root_contents()
        for src_name, asset, label, _ in SCENES:
            export(src_name, asset, colors=args.colors)
            print("scene", asset)
    build_sheet()


if __name__ == "__main__":
    main()