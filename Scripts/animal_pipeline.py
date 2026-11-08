#!/usr/bin/env python3
"""animal_pipeline.py — 小动物素材流水线（豆卡单词）

把一个 1024×1024 的 SVG/PNG 源图，加工成 iOS 能直接用的资源：

  1. 用无头 Chrome 把 SVG 渲染成 PNG（保留透明背景）
  2. 自动裁掉空白边、按比例补成正方形（保证 20 只动物视觉大小一致）
  3. 导出 @1x/@2x/@3x 与 1024 贴纸图
  4. 生成 Xcode 的 .imageset（含 Contents.json）
  5. 可选：多帧合成 APNG / GIF 循环动画

用法
  python animal_pipeline.py sheet  --svg source/juzi.svg --name Juzi --display 橘子 \
      --out ../../BeanMan/Resources/Assets.xcassets/Animals
  python animal_pipeline.py frames --inputs render/juzi-master.png,render/juzi-blink.png \
      --durations 900,120 --out render/juzi-idle.apng

依赖：Pillow、本机 Google Chrome（仅渲染 SVG 时需要）。
"""

from __future__ import annotations

import argparse
import json
import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

from PIL import Image

CHROME_CANDIDATES = [
    r"C:\Program Files\Google\Chrome\Application\chrome.exe",
    r"C:\Program Files (x86)\Google\Chrome\Application\chrome.exe",
    os.path.expandvars(r"%LOCALAPPDATA%\Google\Chrome\Application\chrome.exe"),
    "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
    "/usr/bin/google-chrome",
    "/usr/bin/chromium",
]


def find_chrome() -> str:
    for c in CHROME_CANDIDATES:
        if c and Path(c).exists():
            return c
    raise SystemExit("找不到 Chrome，无法渲染 SVG。可以先用别的工具把 SVG 导成 PNG。")


def render_svg(svg: Path, out_png: Path, size: int = 1024) -> None:
    chrome = find_chrome()
    out_png.parent.mkdir(parents=True, exist_ok=True)
    profile = Path(tempfile.gettempdir()) / "animal-pipeline-chrome"
    cmd = [
        chrome,
        "--headless=new",
        "--no-first-run",
        "--no-default-browser-check",
        f"--user-data-dir={profile}",
        "--disable-gpu",
        "--hide-scrollbars",
        "--default-background-color=00000000",  # 透明底的关键
        f"--window-size={size},{size}",
        f"--screenshot={out_png}",
        svg.resolve().as_uri(),
    ]
    subprocess.run(cmd, capture_output=True, timeout=90)
    if not out_png.exists():
        raise SystemExit(f"渲染失败：{out_png}")


def trim_and_square(img: Image.Image, pad_ratio: float = 0.04) -> Image.Image:
    """裁掉透明空白，再补成正方形（四周留 pad_ratio 的相对边距）。"""
    bbox = img.getchannel("A").getbbox()
    if bbox is None:
        return img
    img = img.crop(bbox)
    side = int(max(img.width, img.height) * (1 + pad_ratio * 2))
    canvas = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    canvas.paste(img, ((side - img.width) // 2, (side - img.height) // 2), img)
    return canvas


def write_imageset(square: Image.Image, out_root: Path, name: str, display: str, one_scale: bool = False) -> Path:
    """生成 Name.imageset（默认 @1x=256 / @2x=512 / @3x=768；one_scale 时只出一张 512 通用图）。"""
    if one_scale:
        imageset = out_root / f"{name}.imageset"
        imageset.mkdir(parents=True, exist_ok=True)
        square.resize((512, 512), Image.LANCZOS).save(imageset / f"{name.lower()}.png")
        contents = {
            "images": [{"filename": f"{name.lower()}.png", "idiom": "universal"}],
            "info": {"author": "xcode", "version": 1},
            "properties": {"template-rendering-intent": "original"},
        }
        (imageset / "Contents.json").write_text(json.dumps(contents, indent=2), encoding="utf-8")
        return imageset
    imageset = out_root / f"{name}.imageset"
    imageset.mkdir(parents=True, exist_ok=True)
    for scale, px in ((1, 256), (2, 512), (3, 768)):
        suffix = "" if scale == 1 else f"@{scale}x"
        square.resize((px, px), Image.LANCZOS).save(imageset / f"{name.lower()}{suffix}.png")
    contents = {
        "images": [
            {"filename": f"{name.lower()}.png", "idiom": "universal", "scale": "1x"},
            {"filename": f"{name.lower()}@2x.png", "idiom": "universal", "scale": "2x"},
            {"filename": f"{name.lower()}@3x.png", "idiom": "universal", "scale": "3x"},
        ],
        "info": {"author": "xcode", "version": 1},
        "properties": {"template-rendering-intent": "original"},
    }
    (imageset / "Contents.json").write_text(json.dumps(contents, indent=2), encoding="utf-8")

    return imageset


def cmd_sheet(args: argparse.Namespace) -> None:
    svg = Path(args.svg).resolve()
    out_root = Path(args.out).resolve()
    work = Path(args.work).resolve() if args.work else svg.parent.parent / "render"
    work.mkdir(parents=True, exist_ok=True)

    master = work / f"{args.name.lower()}-master.png"
    if svg.suffix.lower() == ".svg":
        render_svg(svg, master, size=args.size)
    else:
        master = svg

    img = Image.open(master).convert("RGBA")
    square = trim_and_square(img, pad_ratio=args.pad)

    sticker_file = None
    if args.sticker:
        sticker_dir = Path(args.sticker).resolve()
        sticker_dir.mkdir(parents=True, exist_ok=True)
        sticker_file = sticker_dir / f"{args.name.lower()}-1024.png"
        square.resize((1024, 1024), Image.LANCZOS).save(sticker_file)

    if args.preview:
        preview_dir = Path(args.preview).resolve()
        preview_dir.mkdir(parents=True, exist_ok=True)
        square.resize((512, 512), Image.LANCZOS).save(preview_dir / f"{args.name.lower()}.png")

    imageset = write_imageset(square, out_root, args.name, args.display, one_scale=args.one_scale)
    print(f"[ok] {args.display} -> {imageset}")
    print(f"     master {master}")
    if sticker_file:
        print(f"     sticker {sticker_file}")


def cmd_frames(args: argparse.Namespace) -> None:
    inputs = [Path(p).resolve() for p in args.inputs.split(",")]
    durations = [int(d) for d in args.durations.split(",")]
    if len(inputs) != len(durations):
        raise SystemExit("--inputs 与 --durations 数量必须一致")

    frames = []
    for p in inputs:
        img = Image.open(p).convert("RGBA")
        frames.append(trim_and_square(img, pad_ratio=0.04))

    side = max(f.width for f in frames)
    frames = [f.resize((side, side), Image.LANCZOS) if f.width != side else f for f in frames]

    out = Path(args.out).resolve()
    out.parent.mkdir(parents=True, exist_ok=True)
    frames[0].save(
        out,
        save_all=True,
        append_images=frames[1:],
        duration=durations,
        loop=0,
        disposal=2,
    )
    print(f"动画 {out}（{len(frames)} 帧，共 {sum(durations)} ms 一轮）")


def main() -> None:
    ap = argparse.ArgumentParser(description="豆卡单词 · 小动物素材流水线")
    sub = ap.add_subparsers(dest="cmd", required=True)

    s = sub.add_parser("sheet", help="渲染 SVG 并导出 imageset / 贴纸")
    s.add_argument("--svg", required=True)
    s.add_argument("--name", required=True, help="英文名，用于资源名，如 Juzi")
    s.add_argument("--display", required=True, help="中文名，如 橘子")
    s.add_argument("--out", required=True, help="Assets.xcassets/Animals 目录")
    s.add_argument("--work", default=None, help="中间文件目录，默认 ../render")
    s.add_argument("--size", type=int, default=1024)
    s.add_argument("--pad", type=float, default=0.04)
    s.add_argument("--sticker", default=None, help="贴纸 1024 PNG 的输出目录（可省略）")
    s.add_argument("--preview", default=None, help="512 预览图的输出目录（可省略）")
    s.add_argument("--one-scale", action="store_true", help="只输出一张 512 通用图（表情变体用，省包体）")
    s.set_defaults(func=cmd_sheet)

    f = sub.add_parser("frames", help="多帧合成循环动画")
    f.add_argument("--inputs", required=True, help="逗号分隔的 PNG 路径")
    f.add_argument("--durations", required=True, help="逗号分隔的毫秒数，如 900,120")
    f.add_argument("--out", required=True, help="输出 .apng / .gif")
    f.set_defaults(func=cmd_frames)

    args = ap.parse_args()
    args.func(args)


if __name__ == "__main__":
    main()