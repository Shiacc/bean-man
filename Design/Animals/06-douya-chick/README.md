# 06 豆芽 · 小鸡（Douya）

**角色**：首次引导。刚孵出来、什么都要人带一遍——正好对应「第一次打开 App」。

**性格**：好奇、话多、什么都想啄一下。

## 配色

| 用途 | 色值 |
|---|---|
| 黄 yellow | `#F5C542` |
| 浅黄 light | `#FBE7A0` |
| 喙 beak | `#E88C2E` |
| 描边 outline | `#3A2A22` |
| 腮红 blush | `#F3A183`（55%） |

## 比例

- 头身一体：椭圆 `(512, 556)`，半径 `252 × 262`（唯一只有「一个圆」的角色）
- 肚皮 `158 × 150`，`(512, 642)`
- 翅膀：`42 × 58` 椭圆，中心 `(392, 686)` / `(632, 686)`，旋转 ∓22°，**整只画在身体内部**（画到身体外会露出独立的描边，看起来像贴纸掉了）
- 呆毛：3 条曲线，从 `(512, 300)` 散开
- 脚：两条腿 + 三趾，起点 `y = 812`（低于身体底边才不会被身体压住）
- 描边 11px

## 文件

| 文件 | 说明 |
|---|---|
| `source/douya.svg` | 唯一源文件 |
| `render/douya-master.png` | 1024 渲染稿 |
| `../../BeanMan/Resources/Assets.xcassets/Animals/Douya.imageset/` | 256/512/768 |

## 重新生成

```powershell
$env:PYTHONIOENCODING="utf-8"
python Scripts/animal_pipeline.py sheet `
  --svg Design/Animals/06-douya-chick/source/douya.svg `
  --name Douya --display "豆芽" `
  --out BeanMan/Resources/Assets.xcassets/Animals
```

## 代码用法

```swift
AnimalView(animal: .douya, size: 96)
Animal.douya.accent   // #F5C542
```

## 文案对照

| 场景 | 文案 |
|---|---|
| 欢迎页 | 「先定个小目标？」 |
| 设置每日新词 | 「一天 20 个，不多吧」 |
| 完成引导 | 「可以开始了」 |

## 待补

- [ ] 表情三连：happy / blink / sleepy
- [ ] idle 循环（呆毛摇）
- [ ] 特效贴纸（碎蛋壳）