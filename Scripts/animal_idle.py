#!/usr/bin/env python3
"""给动物做 idle 呼吸动画：整体轻微上下浮动 + 逐帧渲染。

用法：
    python Scripts/animal_idle.py --svg Design/Animals/01-juzi-orange-cat/source/juzi.svg \
        --name juzi-idle --frames 8 --amplitude 3 --out Design/Animals/01-juzi-orange-cat/render/idle

原理：把 SVG 根元素内部的内容包一层 <g transform="translate(0, dy)">，
逐帧 dy 走一个正弦，再用无头 Chrome 渲染成 PNG。
"""
from __future__ import annotations

import argparse
import math
import re
import shutil
import subprocess
import tempfile
from pathlib import Path

from PIL import Image

CHROME_CANDIDATES = [
    r"C:\Program Files\Google\Chrome\Application\chrome.exe",
    r"C:\Program Files (x86)\Google\Chrome\Application\chrome.exe",
    "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
    "/usr/bin/google-chrome",
    "/usr/bin/chromium",
]


def find_chrome() -> str:
    for c in CHROME_CANDIDATES:
        if Path(c).exists():
            return c
    found = shutil.which("chrome") or shutil.which("google-chrome") or shutil.which("chromium")
    if not found:
        raise SystemExit("找不到 Chrome，请用 --chrome 指定")
    return found


def render(chrome: str, svg: Path, png: Path, size: int) -> None:
    profile = Path(tempfile.gettempdir()) / "cr-idle"
    subprocess.run(
        [
            chrome,
            "--headless=new",
            "--no-first-run",
            "--hide-scrollbars",
            f"--user-data-dir={profile}",
            "--default-background-color=00000000",
            f"--window-size={size},{size}",
            f"--screenshot={png}",
            svg.resolve().as_uri(),
        ],
        check=True,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )


def wrap(svg_text: str, dy: float) -> str:
    """把根 svg 的内部内容整体下移 dy。"""
    open_tag = re.search(r"<svg\b[^>]*>", svg_text)
    if not open_tag:
        raise SystemExit("不是 SVG")
    head_end = open_tag.end()
    body_end = svg_text.rindex("</svg>")
    inner = svg_text[head_end:body_end]
    return f"{svg_text[:head_end]}\n<g transform=\"translate(0,{dy:.2f})\">{inner}</g>\n{svg_text[body_end:]}"


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--svg", required=True)
    ap.add_argument("--name", default="idle")
    ap.add_argument("--frames", type=int, default=8)
    ap.add_argument("--amplitude", type=float, default=3.0, help="上下浮动像素（1024 画布）")
    ap.add_argument("--size", type=int, default=1024)
    ap.add_argument("--out", required=True, help="帧输出目录")
    ap.add_argument("--chrome", default=None)
    args = ap.parse_args()

    svg_path = Path(args.svg)
    src = svg_path.read_text(encoding="utf-8")
    out_dir = Path(args.out)
    out_dir.mkdir(parents=True, exist_ok=True)
    chrome = args.chrome or find_chrome()

    with tempfile.TemporaryDirectory() as tmp:
        tmp_svg = Path(tmp) / "frame.svg"
        files = []
        for i in range(args.frames):
            # 正弦：0 → 上浮 → 0 → 下沉，首尾闭合
            dy = -args.amplitude * math.sin(2 * math.pi * i / args.frames)
            tmp_svg.write_text(wrap(src, dy), encoding="utf-8")
            png = out_dir / f"{args.name}-{i:02d}.png"
            render(chrome, tmp_svg, png, args.size)
            files.append(png)

        imgs = [Image.open(f).convert("RGBA") for f in files]
        boxes = [im.getbbox() for im in imgs]
        left = min(b[0] for b in boxes)
        top = min(b[1] for b in boxes)
        right = max(b[2] for b in boxes)
        bottom = max(b[3] for b in boxes)
        box = (left, top, right, bottom)
        # 所有帧用同一个裁剪框，保留相对位移（否则逐帧居中会把上下浮动吃掉）
        crops = [im.crop(box) for im in imgs]
        side = max(max(c.width, c.height) for c in crops)
        centered = []
        for c in crops:
            canvas = Image.new("RGBA", (side, side), (0, 0, 0, 0))
            canvas.paste(c, ((side - c.width) // 2, (side - c.height) // 2), c)
            centered.append(canvas)
        for i, c in enumerate(centered):
            c.save(out_dir / f"{args.name}-{i:02d}.png")
        sheet_grid = Image.new("RGBA", (side * len(centered), side), (0, 0, 0, 0))
        for i, c in enumerate(centered):
            sheet_grid.paste(c, (i * side, 0), c)
        sheet_grid.thumbnail((1600, 400))
        sheet_path = out_dir / f"{args.name}-frames.png"
        sheet_grid.save(sheet_path)
        print(f"[ok] {len(centered)} 帧 → {out_dir}")
        print(f"     预览 {sheet_path}")


if __name__ == "__main__":
    main()