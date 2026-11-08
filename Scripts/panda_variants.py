#!/usr/bin/env python3
"""panda_variants.py — 生成熊猫（竹竹）三个风格变体，便于挑选。

变体：
  A 幼圆（头更大、眼罩更圆、身体更短）
  B 真熊猫（肩带连成一片、眼罩更斜、眼睛更小）
  C 极简贴纸（去细节、大色块、贴纸感）

用法：
  python Scripts/panda_variants.py --out Design/Animals/05-zhuzhu-panda/variants
"""
from __future__ import annotations

import argparse
import subprocess
import sys
import tempfile
from pathlib import Path

STROKE = "#3A2A22"
FUR = "#FFF9F3"
BLACK = "#2E2420"
BLUSH = "#F3A183"

CHROME = [
    r"C:\Program Files\Google\Chrome\Application\chrome.exe",
    "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
    "/usr/bin/google-chrome",
    "/usr/bin/chromium",
]

VARIANTS = {
    "A-young": dict(
        title="A · 幼圆",
        head=(512, 480, 258, 246),
        ear=(84, 0.66, 0.80),
        patch=(76, 98, 12),
        eye=(30, 34, 16),
        body=(322, 620, 702, 894),
        arms=True,
        arm_w=62,
        band=False,
        leg=42,
        blush=True,
    ),
    "B-real": dict(
        title="B · 真熊猫",
        head=(512, 496, 244, 222),
        ear=(92, 0.66, 0.78),
        patch=(70, 94, 24),
        eye=(25, 29, 14),
        body=(330, 648, 694, 902),
        arms=True,
        arm_w=72,
        band=True,
        leg=40,
        blush=False,
    ),
    "C-sticker": dict(
        title="C · 极简贴纸",
        head=(512, 488, 256, 240),
        ear=(88, 0.67, 0.80),
        patch=(82, 106, 6),
        eye=(26, 30, 15),
        body=(326, 620, 698, 898),
        arms=False,
        arm_w=56,
        band=False,
        leg=46,
        blush=True,
    ),
}


def svg_for(p: dict) -> str:
    hx, hy, hrx, hry = p["head"]
    ear_r, ear_dxf, ear_cyf = p["ear"]
    prx, pry, prot = p["patch"]
    erx, ery, pur = p["eye"]
    bx0, by0, bx1, by1 = p["body"]
    ear_dx = hrx * ear_dxf
    ear_cy = hy - hry * ear_cyf

    cx = (bx0 + bx1) / 2
    body = (
        f"M {bx0} {by0 + 116} "
        f"C {bx0 - 18} {by0 + 236} {bx0 + 40} {by1 - 6} {bx0 + 62} {by1} "
        f"L {bx1 - 62} {by1} "
        f"C {bx1 - 40} {by1 - 6} {bx1 + 18} {by0 + 236} {bx1} {by0 + 116} "
        f"C {bx1 - 12} {by0 + 34} {bx1 - 108} {by0} {cx} {by0} "
        f"C {bx0 + 108} {by0} {bx0 + 12} {by0 + 34} {bx0} {by0 + 116} Z"
    )

    arms = ""
    if p["arms"]:
        aw = p["arm_w"]
        arms = (
            f'<path d="M {bx0 - 18} {by0 + 74} '
            f'C {bx0 + 26} {by0 + 132} {bx0 + aw} {by0 + 216} {bx0 + aw} {by1 + 40} '
            f'L {bx0 - 18} {by1 + 40} Z" fill="{BLACK}"/>'
            f'<path d="M {bx1 + 18} {by0 + 74} '
            f'C {bx1 - 26} {by0 + 132} {bx1 - aw} {by0 + 216} {bx1 - aw} {by1 + 40} '
            f'L {bx1 + 18} {by1 + 40} Z" fill="{BLACK}"/>'
        )

    # 肩带：两块斜置的黑色肩片（真熊猫的「黑肩」），比横带自然
    band = ""
    if p["band"]:
        band = (
            f'<ellipse cx="{bx0 + 56}" cy="{by0 + 118}" rx="76" ry="104" fill="{BLACK}" '
            f'transform="rotate(16 {bx0 + 56} {by0 + 118})"/>'
            f'<ellipse cx="{bx1 - 56}" cy="{by0 + 118}" rx="76" ry="104" fill="{BLACK}" '
            f'transform="rotate(-16 {bx1 - 56} {by0 + 118})"/>'
        )

    legs = (
        f'<ellipse cx="{bx0 + 104}" cy="{by1 + 4}" rx="{p["leg"] + 12}" ry="{p["leg"] - 12}" fill="{BLACK}"/>'
        f'<ellipse cx="{bx1 - 104}" cy="{by1 + 4}" rx="{p["leg"] + 12}" ry="{p["leg"] - 12}" fill="{BLACK}"/>'
    )

    belly = (
        f'<ellipse cx="{cx}" cy="{by0 + 160}" rx="{(bx1 - bx0) * 0.29:.0f}" '
        f'ry="{(by1 - by0) * 0.30:.0f}" fill="{FUR}" stroke="none"/>'
    )

    patches = ""
    eyes = ""
    for sign in (-1, 1):
        px = cx + sign * hrx * 0.42
        patches += (
            f'<ellipse cx="{px:.0f}" cy="{hy + 6}" rx="{prx}" ry="{pry}" '
            f'fill="{BLACK}" transform="rotate({sign * prot} {px:.0f} {hy + 6})"/>'
        )
        ex = px + sign * 2
        eyes += (
            f'<ellipse cx="{ex:.0f}" cy="{hy + 4}" rx="{erx}" ry="{ery}" fill="#FFFFFF" stroke="none"/>'
            f'<circle cx="{ex:.0f}" cy="{hy + 6}" r="{pur}" fill="#241C17" stroke="none"/>'
            f'<circle cx="{ex - pur * 0.34:.0f}" cy="{hy - pur * 0.30:.0f}" r="{max(4, pur * 0.32):.0f}" fill="#FFFFFF" stroke="none"/>'
        )

    ears = (
        f'<circle cx="{cx - ear_dx:.0f}" cy="{ear_cy:.0f}" r="{ear_r}" fill="{BLACK}" stroke="{STROKE}" stroke-width="11"/>'
        f'<circle cx="{cx + ear_dx:.0f}" cy="{ear_cy:.0f}" r="{ear_r}" fill="{BLACK}" stroke="{STROKE}" stroke-width="11"/>'
    )

    muzzle_y = hy + hry * 0.46
    muzzle = (
        f'<ellipse cx="{cx}" cy="{muzzle_y:.0f}" rx="{hrx * 0.28:.0f}" ry="{hry * 0.20:.0f}" '
        f'fill="{FUR}" stroke="none"/>'
        f'<path d="M {cx - 30:.0f} {muzzle_y - 34:.0f} Q {cx:.0f} {muzzle_y - 8:.0f} {cx + 30:.0f} {muzzle_y - 34:.0f}" '
        f'fill="none" stroke="{STROKE}" stroke-width="9" stroke-linecap="round"/>'
        f'<path d="M {cx:.0f} {muzzle_y - 12:.0f} L {cx:.0f} {muzzle_y + 16:.0f}" '
        f'fill="none" stroke="{STROKE}" stroke-width="9" stroke-linecap="round"/>'
    )

    blush = ""
    if p["blush"]:
        blush = (
            f'<ellipse cx="{cx - hrx * 0.64:.0f}" cy="{hy + hry * 0.50:.0f}" rx="38" ry="21" fill="{BLUSH}" opacity="0.55" stroke="none"/>'
            f'<ellipse cx="{cx + hrx * 0.64:.0f}" cy="{hy + hry * 0.50:.0f}" rx="38" ry="21" fill="{BLUSH}" opacity="0.55" stroke="none"/>'
        )

    return f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024" width="1024" height="1024">
  <defs>
    <path id="bodyShape" d="{body}"/>
    <clipPath id="bodyClip"><use href="#bodyShape"/></clipPath>
    <ellipse id="headShape" cx="{hx}" cy="{hy}" rx="{hrx}" ry="{hry}"/>
    <clipPath id="headClip"><use href="#headShape"/></clipPath>
  </defs>

  <!-- 身体：白底 → 黑肢 → 奶油肚 → 压描边（描边在头之前，头会盖住上沿） -->
  <use href="#bodyShape" fill="{FUR}"/>
  <g clip-path="url(#bodyClip)">
    {band}
    {arms}
    {legs}
  </g>
  {belly}
  <use href="#bodyShape" fill="none" stroke="{STROKE}" stroke-width="11"/>

  <!-- 耳朵在头之前 -->
  {ears}

  <!-- 头 + 五官，全部裁进头轮廓 -->
  <use href="#headShape" fill="{FUR}"/>
  <g clip-path="url(#headClip)">
    {patches}
    {eyes}
    {muzzle}
    {blush}
  </g>
  <use href="#headShape" fill="none" stroke="{STROKE}" stroke-width="11"/>
</svg>
'''


def render(svg_path: Path, png_path: Path) -> None:
    chrome = next((c for c in CHROME if Path(c).exists()), None)
    if chrome is None:
        sys.exit("找不到 Chrome，无法渲染 PNG")
    cmd = [
        chrome,
        "--headless=new",
        "--no-first-run",
        f"--user-data-dir={Path(tempfile.gettempdir()) / 'panda-shots'}",
        "--default-background-color=00000000",
        "--hide-scrollbars",
        f"--screenshot={png_path.resolve()}",
        "--window-size=1024,1024",
        svg_path.resolve().as_uri(),
    ]
    subprocess.run(cmd, check=False, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default="Design/Animals/05-zhuzhu-panda/variants")
    args = ap.parse_args()
    out = Path(args.out)
    out.mkdir(parents=True, exist_ok=True)
    for slug, p in VARIANTS.items():
        svg = out / f"zhuzhu-{slug}.svg"
        png = out / f"zhuzhu-{slug}.png"
        svg.write_text(svg_for(p), encoding="utf-8")
        render(svg, png)
        print(f"{p['title']:<12} -> {png}")


if __name__ == "__main__":
    main()