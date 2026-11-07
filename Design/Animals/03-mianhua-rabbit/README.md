# 03 棉花 · 垂耳兔（Mianhua）

**角色**：新词。第一次见到一个词的时候，它是那个「有点怕生、慢慢凑过来」的角色。

**性格**：软、慢热。不催你，只在旁边等。

## 配色

| 用途 | 色值 |
|---|---|
| 毛色 fur | `#F2D7C2` |
| 耳内 inner | `#F6C1B4` |
| 奶油 cream | `#FFF9F3` |
| 描边 outline | `#3A2A22` |
| 腮红 blush | `#F3A183`（60%） |

## 比例

- 头椭圆 `(512, 496)`，半径 `250 × 232`
- 垂耳：贴着头两侧下垂，顶端 `y ≈ 392`，耳尖到 `y ≈ 700`
- **垂耳必须画在头之前**：露在头轮廓外的部分才可见，否则描边会横穿脸（本书 v1.0/v1.1 踩过两次）
- 尾巴：右侧毛球 `(672, 832) r 46`，一半被身体压住
- 门牙两小颗，宽 13、高 20
- 描边 11px

## 文件

| 文件 | 说明 |
|---|---|
| `source/mianhua.svg` | 唯一源文件 |
| `render/mianhua-master.png` | 1024 渲染稿 |
| `../../BeanMan/Resources/Assets.xcassets/Animals/Mianhua.imageset/` | 256/512/768 |

## 重新生成

```powershell
$env:PYTHONIOENCODING="utf-8"
python Scripts/animal_pipeline.py sheet `
  --svg Design/Animals/03-mianhua-rabbit/source/mianhua.svg `
  --name Mianhua --display "棉花" `
  --out BeanMan/Resources/Assets.xcassets/Animals
```

## 代码用法

```swift
AnimalView(animal: .mianhua, size: 96)
Animal.mianhua.accent   // #F2D7C2
```

## 文案对照

| 场景 | 文案 |
|---|---|
| 第一个新词 | 「先认识一下，不用记住」 |
| 新词还剩很多 | 「今天的新词有点多，慢慢来」 |
| 新词学完 | 「新词都见过了」 |

## 待补

- [ ] 表情三连：happy / blink / sleepy
- [ ] idle 循环（耳朵轻摆）
- [ ] 特效贴纸（小问号）