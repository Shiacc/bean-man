# 02 团子 · 柴犬（Dango）

**角色**：连续打卡。用户在「连续 N 天」这件事上看到的就是它——它自己也是靠一件小事坚持下来的。

**性格**：稳、话少、有点憨。不喊口号，只会说「今天也来了」。

## 配色

| 用途 | 色值 |
|---|---|
| 毛色 fur | `#D89B4A` |
| 耳内 inner | `#F6C6B0` |
| 奶油 cream | `#FFF1E8` |
| 描边 outline | `#3A2A22` |
| 腮红 blush | `#F3A183`（60%） |

## 比例

- 头椭圆 `(512, 496)`，半径 `250 × 232`
- 身体底边 `y = 906`，最宽 `312`
- 耳：尖三角，顶点 `y ≈ 224`，底座埋进头轮廓内（底座落在头外会露出「小翅膀」）
- 尾巴：身侧的圈，逆时针卷一圈，末端奶油色
- 描边统一 11px，圆角端点

## 文件

| 文件 | 说明 |
|---|---|
| `source/dango.svg` | 唯一源文件，改图只改这里 |
| `render/dango-master.png` | 1024 渲染稿，用于目测 |
| `../../BeanMan/Resources/Assets.xcassets/Animals/Dango.imageset/` | iOS 用 256/512/768 |

## 重新生成

```powershell
$env:PYTHONIOENCODING="utf-8"
python Scripts/animal_pipeline.py sheet `
  --svg Design/Animals/02-dango-shiba/source/dango.svg `
  --name Dango --display "团子" `
  --out BeanMan/Resources/Assets.xcassets/Animals
```

## 代码用法

```swift
AnimalView(animal: .dango, size: 96)          // 常态
AnimalView(animal: .dango, size: 96, expression: .happy)
Animal.dango.accent                            // #D89B4A
```

## 文案对照

| 场景 | 文案 |
|---|---|
| 有连续记录 | 「连续 \(streak) 天，今天也来了」 |
| 快断了（今天没学） | 「今天还差一点点，别断在这儿」 |
| 刚续上 | 「接上了」 |

## 待补

- [ ] 表情三连：happy / blink / sleepy
- [ ] idle 循环（呼吸 + 尾巴轻摆）
- [ ] 256 头像（`Dango.imageset` 已含）
- [ ] 特效贴纸（火焰 + 天数）