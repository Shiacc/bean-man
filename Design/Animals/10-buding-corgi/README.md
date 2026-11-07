# 10 布丁 · 柯基（Buding）

**角色**：完成庆祝。今天背完的那一下，需要一只会摇尾巴的角色。

**性格**：热情、爱凑近、屁股先到。

## 配色

| 用途 | 色值 |
|---|---|
| 橙 fur | `#E39B5C` |
| 耳内 ear | `#C97A43` |
| 奶油 cream | `#FFF6EA` |
| 描边 outline | `#3A2A22` |
| 舌头 tongue | `#F3888C` |

## 比例

- 头椭圆 `(512, 500)`，半径 `244 × 216`
- 大尖耳：底边在头轮廓内，apex `y ≈ 186`（柯基的耳朵必须够高，否则像柴犬）
- 鼻梁白条：从 `(512, 300)` 到 `y = 470`
- 嘴部奶油椭圆 `118 × 86`
- 胸腹奶油色一块从脖子通到 `y = 900`
- 描边 11px

## 文件

| 文件 | 说明 |
|---|---|
| `source/buding.svg` | 唯一源文件 |
| `render/buding-master.png` | 1024 渲染稿 |
| `../../BeanMan/Resources/Assets.xcassets/Animals/Buding.imageset/` | 256/512/768 |

## 重新生成

```powershell
$env:PYTHONIOENCODING="utf-8"
python Scripts/animal_pipeline.py sheet `
  --svg Design/Animals/10-buding-corgi/source/buding.svg `
  --name Buding --display "布丁" `
  --out BeanMan/Resources/Assets.xcassets/Animals
```

## 代码用法

```swift
AnimalView(animal: .buding, size: 96)
    .scaleEffect(isCelebrating ? 1.06 : 1)
Animal.buding.accent   // #E39B5C
```

## 文案对照

| 场景 | 文案 |
|---|---|
| 今日任务完成 | 「今天的词过完了！」 |
| 连打新纪录 | 「第 \(n) 天，稳」 |
| 成就解锁 | 「解锁了「\(name)」」 |

## 待补

- [ ] 表情三连：happy / blink / sleepy
- [ ] idle 循环（摇尾巴 0.9 秒一个来回）
- [ ] 跳跃动作（380ms，用于完成页）