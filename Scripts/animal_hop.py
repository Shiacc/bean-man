#!/usr/bin/env python3
"""给动物做「开心跳」动作：整体上抛 + 落地压扁。

用法：
    python Scripts/animal_hop.py --svg Design/Animals/01-juzi-orange-cat/source/juzi.svg \
        --name juzi-hop --frames 6 --height 26 --out Design/Animals/01-juzi-orange-cat/render/hop

每帧一个 (dy, scale) 关键姿势：
    0 蹲       dy=+6  sy=0.96 sx=1.04
    1 起跳     dy=-10 sy=1.04 sx=0.97
    2 最高点   dy=-26 sy=1.00 sx=1.00
    3 下落     dy=-12 sy=1.02 sx=0.99
    4 落地     dy=+8  sy=0.94 sx=1.05
    5 回正     dy=0   sy=1.00 sx=1.00
以画布底部中心为缩放锚点，所以压扁时脚不会离地。
"""
from __future__ import annotations

import argparse
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

POSES = [
    (6, 1.04, 0.96),
    (-10, 0.97, 1.04),
    (-26, 1.00, 1.00),
    (-12, 0.99, 1.02),
    (8, 1.05, 0.94),
    (0, 1.00, 1.00),
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
    profile = Path(tempfile.gettempdir()) / "cr-hop"
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


def wrap(svg_text: str, dy: float, sx: float, sy: float, anchor_y: float = 902) -> str:
    """以 (512, anchor_y) 为锚点缩放，再整体平移 dy。"""
    m = re.search(r"<svg\b[^>]*>", svg_text)
    if not m:
        raise SystemExit("不是 SVG")
    head_end = m.end()
    body_end = svg_text.rindex("</svg>")
    inner = svg_text[head_end:body_end]
    transform = (
        f"translate(0,{dy:.2f}) "
        f"translate(512,{anchor_y}) scale({sx:.3f},{sy:.3f}) translate(-512,{-anchor_y})"
    )
    return f'{svg_text[:head_end]}\n<g transform="{transform}">{inner}</g>\n{svg_text[body_end:]}'


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--svg", required=True)
    ap.add_argument("--name", default="hop")
    ap.add_argument("--scale", type=float, default=1.0, help="整体姿势幅度（0–1.5）")
    ap.add_argument("--anchor-y", type=float, default=902, help="缩放锚点 y（脚底）")
    ap.add_argument("--size", type=int, default=1024)
    ap.add_argument("--out", required=True)
    ap.add_argument("--chrome", default=None)
    args = ap.parse_args()

    src = Path(args.svg).read_text(encoding="utf-8")
    out_dir = Path(args.out)
    out_dir.mkdir(parents=True, exist_ok=True)
    chrome = args.chrome or find_chrome()

    with tempfile.TemporaryDirectory() as tmp:
        tmp_svg = Path(tmp) / "frame.svg"
        files = []
        for i, (dy, sx, sy) in enumerate(POSES):
            k = args.scale
            dy *= k
            sx = 1 + (sx - 1) * k
            sy = 1 + (sy - 1) * k
            tmp_svg.write_text(wrap(src, dy, sx, sy, args.anchor_y), encoding="utf-8")
            png = out_dir / f"{args.name}-{i:02d}.png"
            render(chrome, tmp_svg, png, args.size)
            files.append(png)

        imgs = [Image.open(f).convert("RGBA") for f in files]
        boxes = [im.getbbox() for im in imgs]
        box = (
            min(b[0] for b in boxes),
            min(b[1] for b in boxes),
            max(b[2] for b in boxes),
            max(b[3] for b in boxes),
        )
        crops = [im.crop(box) for im in imgs]
        side = max(max(c.width, c.height) for c in crops)
        centered = []
        for c in crops:
            canvas = Image.new("RGBA", (side, side), (0, 0, 0, 0))
            canvas.paste(c, ((side - c.width) // 2, (side - c.height) // 2), c)
            centered.append(canvas)
        for i, c in enumerate(centered):
            c.save(out_dir / f"{args.name}-{i:02d}.png")
        grid = Image.new("RGBA", (side * len(centered), side), (0, 0, 0, 0))
        for i, c in enumerate(centered):
            grid.paste(c, (i * side, 0), c)
        grid.thumbnail((1600, 400))
        grid.save(out_dir / f"{args.name}-frames.png")
        print(f"[ok] {len(centered)} 帧 → {out_dir}")


if __name__ == "__main__":
    main()