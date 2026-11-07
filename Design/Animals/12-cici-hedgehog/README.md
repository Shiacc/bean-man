# 12 刺刺 · 刺猬（Cici）

**角色**：错词本。扎手的东西收起来放，正好是「错词」。

**性格**：戒备、慢热、卷起来防御。

## 配色

| 用途 | 色值 |
|---|---|
| 刺 quill | `#8C5C3D` |
| 身体 quillLight | `#A9744F` |
| 脸 face | `#F6E6D2` |
| 描边 outline | `#3A2A22` |
| 腮红 blush | `#F3A183`（55%） |

## 比例

- 刺不是三角形阵列，而是**一整片锯齿斗篷**：底边 `y = 720` 埋在身体里，避免单根三角悬空（v1.0 踩过：三角底边落在身体轮廓外，看起来「刺飞了」）
- 身体 `316...708`，底边 `y = 912`
- 脸：从 `y = 604` 到 `884`，比身体窄一圈，露出的身体就是「刺的边缘」
- 小圆耳 `r 42`，`(372, 648)` / `(652, 648)`
- 描边 11px

## 文件

| 文件 | 说明 |
|---|---|
| `source/cici.svg` | 唯一源文件 |
| `render/cici-master.png` | 1024 渲染稿 |
| `../../BeanMan/Resources/Assets.xcassets/Animals/Cici.imageset/` | 256/512/768 |

## 重新生成

```powershell
$env:PYTHONIOENCODING="utf-8"
python Scripts/animal_pipeline.py sheet `
  --svg Design/Animals/12-cici-hedgehog/source/cici.svg `
  --name Cici --display "刺刺" `
  --out BeanMan/Resources/Assets.xcassets/Animals
```

## 代码用法

```swift
AnimalView(animal: .cici, size: 96)
Animal.cici.accent   // #A9744F
```

## 文案对照

| 场景 | 文案 |
|---|---|
| 错词本为空 | 「没有扎手的词」 |
| 错词很多 | 「\(n) 个，收着慢慢扎」 |
| 移出错词本 | 「这个不扎了」 |

## 待补

- [ ] 表情三连：happy / blink / sleepy
- [ ] 卷起动作（刺立起来，≤1s）
- [ ] 特效贴纸（小刺）