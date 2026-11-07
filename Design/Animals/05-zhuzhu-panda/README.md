# 05 竹竹 · 熊猫（Zhuzhu）

**角色**：复习。到期复习是「稳」的事，交给慢条斯理的角色。

**性格**：慢、稳、爱吃。不抢话。

## 配色

| 用途 | 色值 |
|---|---|
| 墨黑 ink | `#3A2A22` |
| 白 fur | `#FFFFFF` |
| 腮红 blush | `#F3A183`（50%） |

## 比例

- 头椭圆 `(512, 500)`，半径 `252 × 230`
- 耳朵：`r 74`，圆心 `(338, 300)` / `(686, 300)`，画在头之前
- 黑眼圈：`62 × 76` 斜椭圆，左右各旋转 ∓16°
- 身体：从 `y=600` 到 `y=906`，黑肩带用 `clipPath` 裁进身体轮廓
- **描边顺序很关键**：身体填充 → 黑肩带（裁切）→ **身体描边再压一层**，否则肩带边缘会露白缝（v1.0–v1.2 踩了三次）
- 描边 11px

## 文件

| 文件 | 说明 |
|---|---|
| `source/zhuzhu.svg` | 唯一源文件（含 `bodyShape` + `bodyClip`） |
| `render/zhuzhu-master.png` | 1024 渲染稿 |
| `../../BeanMan/Resources/Assets.xcassets/Animals/Zhuzhu.imageset/` | 256/512/768 |

## 重新生成

```powershell
$env:PYTHONIOENCODING="utf-8"
python Scripts/animal_pipeline.py sheet `
  --svg Design/Animals/05-zhuzhu-panda/source/zhuzhu.svg `
  --name Zhuzhu --display "竹竹" `
  --out BeanMan/Resources/Assets.xcassets/Animals
```

## 代码用法

```swift
AnimalView(animal: .zhuzhu, size: 96)
Animal.zhuzhu.accent   // #3A2A22
```

## 文案对照

| 场景 | 文案 |
|---|---|
| 有到期词 | 「\(n) 个到期了，慢慢清」 |
| 复习中 | 「不着急，回想一下」 |
| 复习清空 | 「到期都清完了」 |

## 待补

- [ ] 表情三连：happy / blink / sleepy
- [ ] idle 循环（嚼竹子）
- [ ] 特效贴纸（竹叶）