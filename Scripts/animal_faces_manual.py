# -*- coding: utf-8 -*-
"""给剩下 4 只（竹竹 / 慢慢 / 呱呱 / 咔咔）手写表情变体。

这四只的眼睛不是「双深色椭圆」结构（熊猫是斜椭圆眼罩、树懒天生就是闭眼弧、
青蛙和螃蟹是白眼球 + 深色瞳孔圆），批量脚本认不出来，只能逐只写。

规则仍与批量版一致：只动眼睛，嘴和身体不动。
"""
from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
A = ROOT / "Design" / "Animals"


def apply(src: Path, out: Path, pairs, header: str) -> None:
    text = src.read_text(encoding="utf-8")
    for old, new in pairs:
        if old not in text:
            sys.exit(f"!! {src.name} 中找不到：{old[:70]}")
        text = text.replace(old, new)
    out.write_text(text, encoding="utf-8")
    print("wrote", out.name, f"({header})")


# ---------------- 05 竹竹（熊猫）：深色斜眼罩 + 白色高光 ----------------
PANDA = A / "05-zhuzhu-panda" / "source"
panda_hi = """  <!-- 高光 -->
  <circle cx="424" cy="466" r="20" fill="#FFFFFF"/>
  <circle cx="616" cy="466" r="20" fill="#FFFFFF"/>
  <circle cx="404" cy="510" r="9" fill="#FFFFFF" opacity="0.7"/>
  <circle cx="596" cy="510" r="9" fill="#FFFFFF" opacity="0.7"/>
"""


def panda_arc(kind: str) -> str:
    # 眼罩中心 (416,486) / (608,486)，随眼罩一起旋转 ±16°
    if kind == "happy":
        left = 'M 372 482 Q 416 448 460 482'
        right = 'M 564 482 Q 608 448 652 482'
    else:
        left = 'M 372 486 Q 416 516 460 486'
        right = 'M 564 486 Q 608 516 652 486'
    extra = ""
    if kind == "sleepy":
        extra = """
  <path d="M 700 300 L 730 300 L 700 336 L 732 336" fill="none"
        stroke="#A39D93" stroke-width="7" stroke-linecap="round" opacity="0.75"/>
  <path d="M 752 254 L 774 254 L 752 280 L 776 280" fill="none"
        stroke="#A39D93" stroke-width="7" stroke-linecap="round" opacity="0.75"/>"""
    return f"""  <!-- 眼罩里的闭眼（{kind}） -->
  <g fill="none" stroke="#FFF1E8" stroke-width="13" stroke-linecap="round">
    <g transform="rotate(-16 416 486)"><path d="{left}"/></g>
    <g transform="rotate(16 608 486)"><path d="{right}"/></g>
  </g>{extra}
"""


# ---------------- 07 慢慢（树懒）：天生闭眼弧 ----------------
SLOTH = A / "07-manman-sloth" / "source"
sloth_sleepy_eyes = """  <!-- 睡眼（闭着的弧） -->
  <path d="M 392 470 Q 424 496 456 470" fill="none" stroke="#3A2A22" stroke-width="10" stroke-linecap="round"/>
  <path d="M 568 470 Q 600 496 632 470" fill="none" stroke="#3A2A22" stroke-width="10" stroke-linecap="round"/>
"""
sloth_happy_eyes = """  <!-- 笑眼 -->
  <path d="M 392 476 Q 424 446 456 476" fill="none" stroke="#3A2A22" stroke-width="11" stroke-linecap="round"/>
  <path d="M 568 476 Q 600 446 632 476" fill="none" stroke="#3A2A22" stroke-width="11" stroke-linecap="round"/>
"""
sloth_open_eyes = """  <!-- 睁眼（少见，用在惊讶） -->
  <circle cx="424" cy="470" r="26" fill="#FFF9F3"/>
  <circle cx="600" cy="470" r="26" fill="#FFF9F3"/>
  <circle cx="424" cy="472" r="13" fill="#3A2A22"/>
  <circle cx="600" cy="472" r="13" fill="#3A2A22"/>
"""

# ---------------- 11 呱呱（青蛙）：白眼球 + 深瞳孔 ----------------
FROG = A / "11-guagua-frog" / "source"
frog_pupils = """  <circle cx="412" cy="342" r="30" fill="#3A2A22"/>
  <circle cx="612" cy="342" r="30" fill="#3A2A22"/>
  <circle cx="422" cy="330" r="10" fill="#FFFFFF"/>
  <circle cx="622" cy="330" r="10" fill="#FFFFFF"/>
"""


def frog_arc(kind: str) -> str:
    if kind == "happy":
        a, b = 'M 366 344 Q 394 306 422 344', 'M 566 344 Q 594 306 622 344'
    else:
        a, b = 'M 366 338 Q 394 372 422 338', 'M 566 338 Q 594 372 622 338'
    return f"""  <path d="{a}" fill="none" stroke="#3A2A22" stroke-width="13" stroke-linecap="round"/>
  <path d="{b}" fill="none" stroke="#3A2A22" stroke-width="13" stroke-linecap="round"/>
"""


# ---------------- 17 咔咔（螃蟹）：白眼球 + 深瞳孔 ----------------
CRAB = A / "17-kaka-crab" / "source"
crab_pupils = """  <circle cx="446" cy="458" r="26" fill="#3A2A22"/>
  <circle cx="594" cy="458" r="26" fill="#3A2A22"/>
  <circle cx="454" cy="448" r="8" fill="#FFFFFF"/>
  <circle cx="602" cy="448" r="8" fill="#FFFFFF"/>
"""


def crab_arc(kind: str) -> str:
    if kind == "happy":
        a, b = 'M 406 456 Q 438 424 470 456', 'M 554 456 Q 586 424 618 456'
    else:
        a, b = 'M 406 450 Q 438 484 470 450', 'M 554 450 Q 586 484 618 450'
    return f"""  <path d="{a}" fill="none" stroke="#3A2A22" stroke-width="13" stroke-linecap="round"/>
  <path d="{b}" fill="none" stroke="#3A2A22" stroke-width="13" stroke-linecap="round"/>
"""


def main() -> None:
    for kind in ("blink", "happy", "sleepy"):
        apply(PANDA / "zhuzhu.svg", PANDA / f"zhuzhu-{kind}.svg",
              [(panda_hi, panda_arc(kind))], f"panda {kind}")

    apply(SLOTH / "manman.svg", SLOTH / "manman-blink.svg",
          [(sloth_sleepy_eyes, sloth_happy_eyes.replace("笑眼", "眨眼（同闭眼）"))], "sloth blink")
    apply(SLOTH / "manman.svg", SLOTH / "manman-happy.svg",
          [(sloth_sleepy_eyes, sloth_happy_eyes)], "sloth happy")
    apply(SLOTH / "manman.svg", SLOTH / "manman-surprised.svg",
          [(sloth_sleepy_eyes, sloth_open_eyes)], "sloth surprised")

    frog_white = """  <circle cx="394" cy="330" r="58" fill="#FFFFFF"/>
  <circle cx="630" cy="330" r="58" fill="#FFFFFF"/>
"""
    frog_lid = """  <circle cx="394" cy="330" r="58" fill="#7FB069"/>
  <circle cx="630" cy="330" r="58" fill="#7FB069"/>
"""
    for kind in ("blink", "happy", "sleepy"):
        apply(FROG / "guagua.svg", FROG / f"guagua-{kind}.svg",
              [(frog_pupils, frog_arc(kind)), (frog_white, frog_lid)], f"frog {kind}")

    crab_white = """  <circle cx="438" cy="450" r="54" fill="#FFF3EA" stroke="#3A2A22" stroke-width="11"/>
  <circle cx="586" cy="450" r="54" fill="#FFF3EA" stroke="#3A2A22" stroke-width="11"/>
"""
    crab_lid = """  <circle cx="438" cy="450" r="54" fill="#E2725B" stroke="#3A2A22" stroke-width="11"/>
  <circle cx="586" cy="450" r="54" fill="#E2725B" stroke="#3A2A22" stroke-width="11"/>
"""
    for kind in ("blink", "happy", "sleepy"):
        apply(CRAB / "kaka.svg", CRAB / f"kaka-{kind}.svg",
              [(crab_pupils, crab_arc(kind)), (crab_white, crab_lid)], f"crab {kind}")


if __name__ == "__main__":
    main()