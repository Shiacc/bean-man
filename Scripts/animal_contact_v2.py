from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(".")
CUT = ROOT / "Design/Animals/_ai"
NAMES = [("Zhuzhu","竹竹"),("Juzi","橘子"),("Dango","团子"),("Mianhua","棉花"),("Zhima","芝麻"),
         ("Douya","豆芽"),("Manman","慢慢"),("Paopao","泡泡"),("Shanshan","闪闪"),("Buding","布丁"),
         ("Guagua","呱呱"),("Cici","刺刺"),("Xueqiu","雪球"),("Awu","啊呜"),("Jiujiu","啾啾"),
         ("Juanjuan","卷卷"),("Kaka","咔咔"),("Yunduo","云朵"),("Gulu","咕噜"),("Youzi","小柚")]
COLS, CELL, PAD, LABEL = 5, 300, 18, 26
rows = (len(NAMES) + COLS - 1) // COLS
W = COLS * (CELL + PAD * 2)
H = 96 + rows * (CELL + PAD * 2 + LABEL)
canvas = Image.new("RGB", (W, H), "#FFF1E8")
draw = ImageDraw.Draw(canvas)
title_font = ImageFont.truetype(r"C:\Windows\Fonts\msyh.ttc", 26)
label_font = ImageFont.truetype(r"C:\Windows\Fonts\msyh.ttc", 15)
draw.text((PAD, 30), "豆卡单词 · 20 只小动物（AI 极简贴纸风格 v2）", fill="#1C1B18", font=title_font)
for i, (name, cn) in enumerate(NAMES):
    p = CUT / f"{name.lower()}-cut.png"
    if not p.exists():
        continue
    img = Image.open(p).convert("RGBA")
    img.thumbnail((CELL, CELL), Image.LANCZOS)
    x = (i % COLS) * (CELL + PAD * 2) + PAD
    y = 96 + (i // COLS) * (CELL + PAD * 2 + LABEL) + PAD
    canvas.paste(img, (x + (CELL - img.width) // 2, y + (CELL - img.height) // 2), img)
    draw.text((x + CELL // 2 - 26, y + CELL + 8), f"{cn} {name}", fill="#6E6962", font=label_font)
out = ROOT / "Design/Animals/contact-sheet-v2.png"
canvas.save(out)
print(out, canvas.size)
