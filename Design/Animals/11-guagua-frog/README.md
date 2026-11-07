# 11 呱呱 · 青蛙（Guagua）

**角色**：补签 / 断签恢复。「忘了几天」这件事，用一只蹲在荷叶上的角色说会轻一点。

**性格**：乐观、嗓门大、爱蹦。

## 配色

| 用途 | 色值 |
|---|---|
| 绿 green | `#7FB069` |
| 深绿 greenDark | `#5F8F4E` |
| 奶油 cream | `#F7F3E2` |
| 描边 outline | `#3A2A22` |
| 舌头 tongue | `#F3888C` |

## 比例

- 头椭圆 `(512, 516)`，半径 `252 × 196`（比其它角色更扁更宽）
- 眼球凸在头顶：`r 96` 的绿球 + `r 58` 白眼球 + `r 30` 瞳孔，圆心 `(394, 330)` / `(630, 330)`
- 嘴：一条大笑弧 `M 392 570 C 440 670 584 670 632 570`，内填 `#3A2A22`，底下压一条粉色舌头
- 肚子 `126 × 100`，`(512, 800)`
- 描边 11px

## 文件

| 文件 | 说明 |
|---|---|
| `source/guagua.svg` | 唯一源文件 |
| `render/guagua-master.png` | 1024 渲染稿 |
| `../../BeanMan/Resources/Assets.xcassets/Animals/Guagua.imageset/` | 256/512/768 |

## 重新生成

```powershell
$env:PYTHONIOENCODING="utf-8"
python Scripts/animal_pipeline.py sheet `
  --svg Design/Animals/11-guagua-frog/source/guagua.svg `
  --name Guagua --display "呱呱" `
  --out BeanMan/Resources/Assets.xcassets/Animals
```

## 代码用法

```swift
AnimalView(animal: .guagua, size: 96)
Animal.guagua.accent   // #7FB069
```

## 文案对照

| 场景 | 文案 |
|---|---|
| 断签后 | 「昨天没来，今天补上」 |
| 连续中断 | 「重新开始也行」 |
| 补签成功 | 「接上了」 |

## 待补

- [ ] 表情三连：happy / blink / sleepy
- [ ] 跳跃动作（380ms）
- [ ] 特效贴纸（水花 / 荷叶）