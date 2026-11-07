# 09 闪闪 · 萤火虫（Shanshan）

**角色**：夜间特效 / 深色模式。黑底上唯一不会消失的角色。

**性格**：安静、忽明忽暗、喜欢在暗处待着。

## 配色

| 用途 | 色值 |
|---|---|
| 尾灯 glow | `#F2C14E` |
| 身体 body | `#6B5B3E` |
| 翅膀 wing | `#FFE9A8`（55%） |
| 描边 outline | `#3A2A22` |
| 腮红 blush | `#F3A183`（55%） |

## 比例

- 头 `r 128`，`(512, 400)`
- 身体椭圆 `168 × 186`，`(512, 640)`
- 尾灯：外圈 `92 × 70`，内圈高光 `58 × 40`
- 上翅：`132 × 80` 旋转 ∓24°；下翅：`92 × 54` 旋转 ∓8°
- 触角末端小球 `r 14`
- **渐变与光晕不进 SVG**：asset 里只有实色，光晕交给运行时 `shadow(color: .brand, radius: 24)`（同 `_风格规范.md` 的「禁渐变」）
- 描边 11px

## 文件

| 文件 | 说明 |
|---|---|
| `source/shanshan.svg` | 唯一源文件 |
| `render/shanshan-master.png` | 1024 渲染稿 |
| `../../BeanMan/Resources/Assets.xcassets/Animals/Shanshan.imageset/` | 256/512/768 |

## 重新生成

```powershell
$env:PYTHONIOENCODING="utf-8"
python Scripts/animal_pipeline.py sheet `
  --svg Design/Animals/09-shanshan-firefly/source/shanshan.svg `
  --name Shanshan --display "闪闪" `
  --out BeanMan/Resources/Assets.xcassets/Animals
```

## 代码用法

```swift
AnimalView(animal: .shanshan, size: 96)
    .shadow(color: Theme.Palette.brand.opacity(0.35), radius: 24)
Animal.shanshan.accent   // #F2C14E
```

## 文案对照

| 场景 | 文案 |
|---|---|
| 深色模式 | 「晚上也能看」 |
| 夜间最后一张 | 「这张看完就睡吧」 |
| 连续打卡 | 「第 \(n) 天，还亮着」 |

## 待补

- [ ] 表情三连：happy / blink / sleepy
- [ ] idle 循环（尾灯呼吸，2.6 秒一个周期）
- [ ] 特效贴纸（光点拖尾）