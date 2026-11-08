# -*- coding: utf-8 -*-
"""把动物 PNG 压成调色板图（PNG8 + alpha）。

这些都是纯色扁平图，256 色足够；压缩能把素材从 ~9MB 降到 ~2MB，不影响观感。
只处理 Assets.xcassets/Animals 下的 png，不碰源 SVG。
"""
from __future__ import annotations

import sys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
TARGET = ROOT / "BeanMan" / "Resources" / "Assets.xcassets" / "Animals"


def shrink(path: Path, colors: int = 64) -> tuple[int, int]:
    before = path.stat().st_size
    img = Image.open(path).convert("RGBA")
    # FASTOCTREE 保留 alpha；dither=NONE 让边缘保持干净（扁平图不需要抖动）
    quant = img.quantize(colors=colors, method=Image.FASTOCTREE, dither=Image.Dither.NONE)
    quant.save(path, "PNG", optimize=True)
    after = path.stat().st_size
    return before, after


def main() -> None:
    if not TARGET.is_dir():
        sys.exit(f"找不到 {TARGET}")
    total_before = total_after = 0
    count = 0
    for p in sorted(TARGET.rglob("*.png")):
        b, a = shrink(p)
        total_before += b
        total_after += a
        count += 1
    print(f"{count} 张：{total_before/1e6:.2f} MB -> {total_after/1e6:.2f} MB "
          f"（省 {(1 - total_after/max(total_before,1))*100:.0f}%）")


if __name__ == "__main__":
    main()