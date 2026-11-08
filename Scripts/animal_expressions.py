# -*- coding: utf-8 -*-
"""生成橘子 / 布丁的表情变体 SVG（sleepy / surprised / happy / blink）。

做法：读基础 SVG，只替换「眼睛块」和「嘴块」，其余几何完全不动 —— 保证同一套比例。
找不到待替换片段时直接报错，避免静默生成一张没变的图。
"""
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
ANIMALS = ROOT / "Design" / "Animals"

JUZI = ANIMALS / "01-juzi-orange-cat" / "source"
BUDING = ANIMALS / "10-buding-corgi" / "source"

# ---------- 橘子 ----------
JUZI_EYES = """  <!-- 眼睛 -->
  <ellipse cx="426" cy="494" rx="55" ry="61" fill="#3A2A22"/>
  <ellipse cx="598" cy="494" rx="55" ry="61" fill="#3A2A22"/>
  <circle cx="407" cy="471" r="17" fill="#FFFFFF"/>
  <circle cx="579" cy="471" r="17" fill="#FFFFFF"/>
  <circle cx="445" cy="519" r="8" fill="#FFFFFF" opacity="0.75"/>
  <circle cx="617" cy="519" r="8" fill="#FFFFFF" opacity="0.75"/>
"""

JUZI_SLEEPY_EYES = """  <!-- 眼睛（困：向下闭合 + 眼皮重） -->
  <path d="M 366 496 Q 426 544 486 496" class="ln" stroke-width="11"/>
  <path d="M 538 496 Q 598 544 658 496" class="ln" stroke-width="11"/>
  <path d="M 372 486 L 356 470 M 652 486 L 668 470" class="ln" stroke-width="7" opacity="0.8"/>
"""

JUZI_SURPRISED_EYES = """  <!-- 眼睛（惊讶：白眼球 + 小瞳孔） -->
  <ellipse cx="426" cy="494" rx="58" ry="62" fill="#FFFFFF" stroke="#3A2A22" stroke-width="10"/>
  <ellipse cx="598" cy="494" rx="58" ry="62" fill="#FFFFFF" stroke="#3A2A22" stroke-width="10"/>
  <circle cx="426" cy="500" r="27" fill="#3A2A22"/>
  <circle cx="598" cy="500" r="27" fill="#3A2A22"/>
  <circle cx="417" cy="489" r="9" fill="#FFFFFF"/>
  <circle cx="589" cy="489" r="9" fill="#FFFFFF"/>
"""

JUZI_MOUTH = """  <!-- 嘴 -->
  <path d="M 512 570 C 512 602 484 612 467 595" class="ln" stroke-width="9"/>
  <path d="M 512 570 C 512 602 540 612 557 595" class="ln" stroke-width="9"/>
"""

JUZI_SLEEPY_MOUTH = """  <!-- 嘴（困：小圆口） -->
  <ellipse cx="512" cy="612" rx="17" ry="20" fill="#C2571F" stroke="#3A2A22" stroke-width="8"/>
  <!-- 睡意 -->
  <g class="ln" stroke-width="7" opacity="0.55">
    <path d="M 706 300 L 736 300 L 706 336 L 738 336"/>
    <path d="M 758 252 L 780 252 L 758 278 L 782 278"/>
  </g>
"""

JUZI_SURPRISED_MOUTH = """  <!-- 嘴（惊讶：张大） -->
  <ellipse cx="512" cy="608" rx="30" ry="38" fill="#C2571F" stroke="#3A2A22" stroke-width="8"/>
  <ellipse cx="512" cy="626" rx="16" ry="12" fill="#F3888C"/>
"""

# ---------- 布丁 ----------
BUDING_EYES = """  <!-- 眼 -->
  <g>
    <ellipse cx="426" cy="486" rx="44" ry="48" fill="#3A2A22"/>
    <ellipse cx="598" cy="486" rx="44" ry="48" fill="#3A2A22"/>
    <circle cx="410" cy="468" r="14" fill="#FFFFFF"/>
    <circle cx="582" cy="468" r="14" fill="#FFFFFF"/>
  </g>
"""

BUDING_HAPPY_EYES = """  <!-- 眼（开心：弯成上弧） -->
  <path d="M 384 494 Q 426 452 468 494" class="ln" stroke-width="12"/>
  <path d="M 556 494 Q 598 452 640 494" class="ln" stroke-width="12"/>
"""

BUDING_BLINK_EYES = """  <!-- 眼（眨眼：一条向下弧） -->
  <path d="M 384 494 Q 426 528 468 494" class="ln" stroke-width="12"/>
  <path d="M 556 494 Q 598 528 640 494" class="ln" stroke-width="12"/>
"""

BUDING_SLEEPY_EYES = """  <!-- 眼（困：闭合 + 眼皮重） -->
  <path d="M 380 492 Q 426 534 472 492" class="ln" stroke-width="12"/>
  <path d="M 552 492 Q 598 534 644 492" class="ln" stroke-width="12"/>
  <path d="M 386 482 L 372 468 M 638 482 L 652 468" class="ln" stroke-width="7" opacity="0.8"/>
"""

BUDING_SURPRISED_EYES = """  <!-- 眼（惊讶：白眼球 + 小瞳孔） -->
  <ellipse cx="426" cy="486" rx="50" ry="54" fill="#FFFFFF" stroke="#3A2A22" stroke-width="9"/>
  <ellipse cx="598" cy="486" rx="50" ry="54" fill="#FFFFFF" stroke="#3A2A22" stroke-width="9"/>
  <circle cx="426" cy="492" r="24" fill="#3A2A22"/>
  <circle cx="598" cy="492" r="24" fill="#3A2A22"/>
  <circle cx="417" cy="481" r="8" fill="#FFFFFF"/>
  <circle cx="589" cy="481" r="8" fill="#FFFFFF"/>
"""

BUDING_MOUTH = """  <!-- 笑 -->
  <path d="M 512 580 L 512 594 M 512 594 C 512 614 490 622 478 612 M 512 594 C 512 614 534 622 546 612"
        fill="none" stroke="#3A2A22" stroke-width="9" stroke-linecap="round"/>

  <!-- 舌头（开心） -->
  <path d="M 500 604 C 500 630 524 630 524 604 Z" fill="#F3888C" stroke="#3A2A22" stroke-width="6"/>
"""

BUDING_BLINK_MOUTH = """  <!-- 嘴（平静：小笑） -->
  <path d="M 512 580 L 512 594 M 512 594 C 512 610 492 616 482 608 M 512 594 C 512 610 532 616 542 608"
        fill="none" stroke="#3A2A22" stroke-width="9" stroke-linecap="round"/>
"""

BUDING_SLEEPY_MOUTH = """  <!-- 嘴（困：小圆口） -->
  <ellipse cx="512" cy="612" rx="14" ry="16" fill="#3A2A22" opacity="0.85"/>
  <!-- 睡意 -->
  <g class="ln" stroke-width="7" opacity="0.55">
    <path d="M 716 306 L 744 306 L 716 340 L 746 340"/>
    <path d="M 766 260 L 786 260 L 766 284 L 788 284"/>
  </g>
"""

BUDING_SURPRISED_MOUTH = """  <!-- 嘴（惊讶：张大） -->
  <ellipse cx="512" cy="606" rx="28" ry="34" fill="#3A2A22"/>
  <ellipse cx="512" cy="622" rx="14" ry="10" fill="#F3888C"/>
"""


def variant(src: Path, out: Path, pairs, header: str) -> None:
    text = src.read_text(encoding="utf-8")
    for old, new in pairs:
        if old not in text:
            sys.exit(f"!! 在 {src.name} 里找不到片段：\n{old[:80]}")
        text = text.replace(old, new)
    text = text.replace("<!-- 布丁 · 柯基 v1.0 ｜ 豆卡单词",
                        f"<!-- 布丁 · 柯基 · {header} ｜ 豆卡单词")
    text = text.replace("<!-- 橘子 · 橘猫 v1.0 ｜ 豆卡单词",
                        f"<!-- 橘子 · 橘猫 · {header} ｜ 豆卡单词")
    out.write_text(text, encoding="utf-8")
    print("wrote", out.name)


def main() -> None:
    if not JUZI.joinpath("juzi.svg").exists():
        sys.exit("找不到 juzi.svg")

    variant(JUZI / "juzi.svg", JUZI / "juzi-sleepy.svg",
            [(JUZI_EYES, JUZI_SLEEPY_EYES), (JUZI_MOUTH, JUZI_SLEEPY_MOUTH)], "sleepy")
    variant(JUZI / "juzi.svg", JUZI / "juzi-surprised.svg",
            [(JUZI_EYES, JUZI_SURPRISED_EYES), (JUZI_MOUTH, JUZI_SURPRISED_MOUTH)], "surprised")

    variant(BUDING / "buding.svg", BUDING / "buding-happy.svg",
            [(BUDING_EYES, BUDING_HAPPY_EYES)], "happy")
    variant(BUDING / "buding.svg", BUDING / "buding-blink.svg",
            [(BUDING_EYES, BUDING_BLINK_EYES), (BUDING_MOUTH, BUDING_BLINK_MOUTH)], "blink")
    variant(BUDING / "buding.svg", BUDING / "buding-sleepy.svg",
            [(BUDING_EYES, BUDING_SLEEPY_EYES), (BUDING_MOUTH, BUDING_SLEEPY_MOUTH)], "sleepy")
    variant(BUDING / "buding.svg", BUDING / "buding-surprised.svg",
            [(BUDING_EYES, BUDING_SURPRISED_EYES), (BUDING_MOUTH, BUDING_SURPRISED_MOUTH)], "surprised")


if __name__ == "__main__":
    main()