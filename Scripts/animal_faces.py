# -*- coding: utf-8 -*-
"""给「只有主立绘」的小动物批量补三种表情：blink / happy / sleepy。

原理：所有角色都用「两个深色竖椭圆 + 白色高光圆」画眼睛。
脚本按几何找出这两只眼睛，把椭圆换成弧线（闭眼 / 笑眼），并把高光圆一起去掉。
嘴和身体一律不动 —— 换表情不该改比例。

橘子、布丁已经有手工表情（见 animal_expressions.py），这里默认跳过。
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ANIMALS = ROOT / "Design" / "Animals"

EYE_FILLS = ('fill="#3A2A22"', "fill='#3A2A22'")
ELLIPSE_RE = re.compile(r'<ellipse\b([^>]*?)/>', re.S)
CIRCLE_RE = re.compile(r'<circle\b([^>]*?)/>', re.S)
ATTR_RE = re.compile(r'(\w[\w-]*)="([^"]*)"')

HAND_MADE = {"juzi", "buding"}
# 这些角色的「眉毛」在闭眼时会被误读成眼睛，生成闭眼变体时一并去掉
BROWS = {"dango": "<!-- 柴犬眉毛：两点奶油 -->"}

def drop_brows(text: str, slug: str) -> str:
    marker = BROWS.get(slug)
    if not marker:
        return text
    i = text.find(marker)
    if i < 0:
        return text
    j = text.find("</g>", i)
    if j < 0:
        return text
    return text[:i] + text[j + 4:]


def attrs(tag: str) -> dict[str, str]:
    return dict(ATTR_RE.findall(tag))


def num(d: dict[str, str], key: str, default: float = 0.0) -> float:
    try:
        return float(d.get(key, default))
    except ValueError:
        return default


def find_eyes(text: str):
    cands = []
    for m in ELLIPSE_RE.finditer(text):
        d = attrs(m.group(1))
        if not any(f in m.group(0) for f in EYE_FILLS):
            continue
        rx, ry = num(d, "rx"), num(d, "ry")
        if 24 <= rx <= 72 and ry >= rx * 0.85:
            cands.append((m, num(d, "cx"), num(d, "cy"), rx, ry))
    # 眼睛成对出现：cy 接近
    pairs = []
    for i in range(len(cands)):
        for j in range(i + 1, len(cands)):
            if abs(cands[i][2] - cands[j][2]) < 8:
                pairs.append((cands[i], cands[j]))
    if not pairs:
        return []
    # 取「最像眼睛」的一对：rx 最大
    return list(max(pairs, key=lambda p: p[0][3] + p[1][3]))


def arc(cx: float, cy: float, rx: float, ry: float, kind: str) -> str:
    """把一只眼睛换成一条弧线。"""
    w = max(11.0, ry * 0.23)
    half = rx * 0.95
    if kind == "blink":
        # 闭眼：轻微下垂的弧
        top = cy + ry * 0.10
        ctrl = cy + ry * 0.85
    elif kind == "happy":
        # 笑眼：上拱
        top = cy + ry * 0.22
        ctrl = cy - ry * 0.62
    else:  # sleepy
        top = cy + ry * 0.18
        ctrl = cy + ry * 0.95
    path = (
        f'<path d="M {cx - half:.1f} {top:.1f} '
        f'Q {cx:.1f} {ctrl:.1f} {cx + half:.1f} {top:.1f}" '
        f'fill="none" stroke="#3A2A22" stroke-width="{w:.1f}" stroke-linecap="round"/>'
    )
    if kind == "sleepy":
        # 眼皮：眼角两根短线
        path += (
            f'<path d="M {cx - half - 6:.1f} {top - 8:.1f} L {cx - half - 18:.1f} {top - 20:.1f}" '
            f'fill="none" stroke="#3A2A22" stroke-width="{w * 0.6:.1f}" stroke-linecap="round" opacity="0.85"/>'
            f'<path d="M {cx + half + 6:.1f} {top - 8:.1f} L {cx + half + 18:.1f} {top - 20:.1f}" '
            f'fill="none" stroke="#3A2A22" stroke-width="{w * 0.6:.1f}" stroke-linecap="round" opacity="0.85"/>'
        )
    return path


def transform(text: str, kind: str) -> str | None:
    eyes = find_eyes(text)
    if len(eyes) != 2:
        return None

    out = text
    for (m, cx, cy, rx, ry) in eyes:
        out = out.replace(m.group(0), arc(cx, cy, rx, ry, kind), 1)

    # 清掉落在眼睛范围内的白色高光（闭眼时它们会浮在脸上）
    def drop_highlight(m: re.Match) -> str:
        d = attrs(m.group(1))
        if d.get("fill") != "#FFFFFF":
            return m.group(0)
        x, y, r = num(d, "cx"), num(d, "cy"), num(d, "r")
        for (_m, cx, cy, rx, ry) in eyes:
            if abs(x - cx) <= rx + 10 and abs(y - cy) <= ry + 10 and r <= 24:
                return ""
        return m.group(0)

    out = CIRCLE_RE.sub(drop_highlight, out)
    return out


def main() -> None:
    made, skipped = [], []
    for folder in sorted(p for p in ANIMALS.iterdir() if p.is_dir()):
        src = folder / "source"
        if not src.is_dir():
            continue
        svgs = [p for p in src.glob("*.svg") if "-" not in p.stem]
        if len(svgs) != 1:
            continue
        base = svgs[0]
        slug = base.stem
        if slug in HAND_MADE:
            skipped.append((slug, "手工表情"))
            continue
        text = base.read_text(encoding="utf-8")
        for kind in ("blink", "happy", "sleepy"):
            variant = transform(text, kind)
            if variant is None:
                skipped.append((slug, "找不到成对的眼睛椭圆"))
                break
            variant = drop_brows(variant, slug)
            (src / f"{slug}-{kind}.svg").write_text(variant, encoding="utf-8")
        else:
            made.append(slug)

    print(f"生成 {len(made)} 只：{', '.join(made) if made else '—'}")
    if skipped:
        print("跳过：")
        for slug, why in skipped:
            print(f"  - {slug}: {why}")


if __name__ == "__main__":
    main()