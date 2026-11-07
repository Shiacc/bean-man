# 07 慢慢 · 树懒（Manman）

**角色**：提醒。「到点了」这种话，从一个永远不着急的角色嘴里说出来，压力最小。

**性格**：慢、困、随和。句子里常出现「不急」。

## 配色

| 用途 | 色值 |
|---|---|
| 毛 fur | `#8C7A66` |
| 深毛 furDark | `#6F6053` |
| 脸 face | `#F3E4D3` |
| 描边 outline | `#3A2A22` |
| 腮红 blush | `#F3A183`（50%） |

## 比例

- 头椭圆 `(512, 494)`，半径 `248 × 226`
- 脸盘 `176 × 164`，`(512, 530)`
- 眼罩：`72 × 54` 斜椭圆，旋转 ∓10°；眼睛是**闭着的弧线**（`Q` 二次曲线），这是它「困」的标志
- 耳朵 `r 52`，画在头之前
- 长手臂：从肩 `(330, 640)` 下垂到 `y = 880`，末端爪子 `34 × 24`
- 描边 11px

## 文件

| 文件 | 说明 |
|---|---|
| `source/manman.svg` | 唯一源文件 |
| `render/manman-master.png` | 1024 渲染稿 |
| `../../BeanMan/Resources/Assets.xcassets/Animals/Manman.imageset/` | 256/512/768 |

## 重新生成

```powershell
$env:PYTHONIOENCODING="utf-8"
python Scripts/animal_pipeline.py sheet `
  --svg Design/Animals/07-manman-sloth/source/manman.svg `
  --name Manman --display "慢慢" `
  --out BeanMan/Resources/Assets.xcassets/Animals
```

## 代码用法

```swift
AnimalView(animal: .manman, size: 96)
Animal.manman.accent   // #8C7A66
```

## 文案对照

| 场景 | 文案 |
|---|---|
| 提醒设置 | 「20:00 提醒你，不急」 |
| 通知正文 | 「到点了，慢慢来」 |
| 今天没学 | 「今天不学也行」 |

## 待补

- [ ] 表情三连：happy / blink / sleepy
- [ ] idle 循环（呼吸 4 秒一个来回，比其他角色慢）
- [ ] 特效贴纸（Zzz）