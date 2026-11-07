# 17 咔咔 · 螃蟹（Kaka）

**角色**：拼写错误 / 错题。「咔」一下夹住写错的词。

**配色**：shell `#E2725B`、shellDark `#C4573F`、cream `#FFF3EA`、描边 `#3A2A22`。

**比例**：身体 `(512,700) rx 212 ry 176`；眼睛在**柄**上（`M 452 550 L 440 470`），柄 14px；钳子左右各一，从肩部 `(330,560)`/`(694,560)` 伸出；腿是 18px 圆头曲线；描边 11px。

**文件**：`source/kaka.svg`、`render/kaka-master.png`、`Assets.xcassets/Animals/Kaka.imageset`。

**重新生成**

```powershell
$env:PYTHONIOENCODING="utf-8"
python Scripts/animal_pipeline.py sheet `
  --svg Design/Animals/17-kaka-crab/source/kaka.svg `
  --name Kaka --display "咔咔" `
  --out BeanMan/Resources/Assets.xcassets/Animals
```

**文案**：「差一个字母」「咔，收进错词本」「再拼一次」。

**待补**：表情三连、夹一下动作、气泡贴纸。