# 08 泡泡 · 水獭（Paopao）

**角色**：测试。做题像玩水，答错也不疼。

**性格**：爱玩、爱现、手里总捏着点什么。

## 配色

| 用途 | 色值 |
|---|---|
| 青 teal | `#6FA8A0` |
| 深青 tealDark | `#558A83` |
| 奶油 cream | `#F6EFE4` |
| 描边 outline | `#3A2A22` |
| 腮红 blush | `#F3A183`（50%） |

## 比例

- 头椭圆 `(512, 496)`，半径 `246 × 222`
- 嘴部奶油区：**两个圆 + 一个圆角矩形拼成「八」字形**（`(462,566)`、`(562,566)` 各 `r 82`）——单用一个椭圆会显得像熊
- 耳朵 `r 52`，圆心 `(342, 332)` / `(682, 332)`
- 前爪：`56 × 44` 旋转椭圆，抱在胸前 `y = 742`
- 脚：`52 × 32`，`y = 888`
- 描边 11px

## 文件

| 文件 | 说明 |
|---|---|
| `source/paopao.svg` | 唯一源文件 |
| `render/paopao-master.png` | 1024 渲染稿 |
| `../../BeanMan/Resources/Assets.xcassets/Animals/Paopao.imageset/` | 256/512/768 |

## 重新生成

```powershell
$env:PYTHONIOENCODING="utf-8"
python Scripts/animal_pipeline.py sheet `
  --svg Design/Animals/08-paopao-otter/source/paopao.svg `
  --name Paopao --display "泡泡" `
  --out BeanMan/Resources/Assets.xcassets/Animals
```

## 代码用法

```swift
AnimalView(animal: .paopao, size: 96)
Animal.paopao.accent   // #6FA8A0
```

## 文案对照

| 场景 | 文案 |
|---|---|
| 测试开始 | 「10 道题，随便玩」 |
| 答错 | 「没事，这题记一下」 |
| 测试结束 | 「\(n)/10，比上次好」 |

## 待补

- [ ] 表情三连：happy / blink / sleepy
- [ ] idle 循环（手里的泡泡飘起来）
- [ ] 特效贴纸（水花）