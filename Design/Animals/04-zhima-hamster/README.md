# 04 芝麻 · 仓鼠（Zhima）

**角色**：生词本。把词「存起来」这件事，交给会囤东西的角色。

**性格**：囤积癖、动作快、爱炫耀存货。

## 配色

| 用途 | 色值 |
|---|---|
| 毛色 fur | `#C9A227` |
| 耳内 inner | `#F6C1B4` |
| 奶油 cream | `#FFF9F3` |
| 描边 outline | `#3A2A22` |
| 腮红 blush | `#F3A183`（55%） |

## 比例

- 头椭圆 `(512, 512)`，半径 `262 × 222`（比其他角色更扁）
- 腮帮子：两侧各一个 `86 × 74` 椭圆，圆心 `(330, 588)` / `(694, 588)`，**画在头之后**才露得出来
- 圆耳：`r 62`，圆心 `(352, 326)` / `(672, 326)`，画在头之前
- 身体比猫更矮更宽：底边 `y = 912`
- 肚子奶油色椭圆 `126 × 96`
- 描边 11px

## 文件

| 文件 | 说明 |
|---|---|
| `source/zhima.svg` | 唯一源文件 |
| `render/zhima-master.png` | 1024 渲染稿 |
| `../../BeanMan/Resources/Assets.xcassets/Animals/Zhima.imageset/` | 256/512/768 |

## 重新生成

```powershell
$env:PYTHONIOENCODING="utf-8"
python Scripts/animal_pipeline.py sheet `
  --svg Design/Animals/04-zhima-hamster/source/zhima.svg `
  --name Zhima --display "芝麻" `
  --out BeanMan/Resources/Assets.xcassets/Animals
```

## 代码用法

```swift
AnimalView(animal: .zhima, size: 96)
Animal.zhima.accent   // #C9A227
```

## 文案对照

| 场景 | 文案 |
|---|---|
| 加入生词本 | 「收好了，攒着」 |
| 生词本为空 | 「还没囤东西」 |
| 生词本很多 | 「囤了 \(count) 个，慢慢消化」 |

## 待补

- [ ] 表情三连：happy / blink / sleepy
- [ ] idle 循环（腮帮子鼓一下）
- [ ] 特效贴纸（星星 +N）