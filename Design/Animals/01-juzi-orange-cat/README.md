# 01 · 橘子（Juzi）· 橘猫

> 豆卡单词的第一只小动物，也是「小豆的朋友们」的门面。
> 它不抢小豆的台词，只负责表情：**在三秒钟内让人想再背一个词。**

## 一、角色设定

| 项 | 内容 |
|---|---|
| 名字 | 橘子（英文名 Juzi） |
| 物种 | 橘猫（中华田园猫） |
| 性格 | 贪吃、黏人、记性好；口头禅在心里是「再看一眼就好」 |
| 功能 | 学习陪伴主角色：今日页常驻、学习卡角标、连续打卡的情绪反馈 |
| 出场原则 | 不遮挡文字、不覆盖按钮；同一屏只出现一次 |
| 和用户的关系 | 同桌，不是老师。它也会忘，也会犯困，所以用户不怕它 |

## 二、形体比例

```
画布 1024×1024
头：椭圆 500×464，中心 (512, 496)   → 占宽 49%
身：宽 276，高 320，底部 y=902        → 头宽 ≈ 身宽 × 1.8
眼：椭圆 110×122，中心 (426, 494)/(598, 494)，眼距 172
描边：11 px，#3A2A22
脚底：y=902（= 画布 88%），20 只动物统一这条线
```

配色：身体 `#E4703A`｜条纹 `#C2571F`｜奶油 `#FFF1E8`｜描边 `#3A2A22`｜腮红 `#F3A183` 60%｜内耳 `#F6C6B0`

## 三、表情与动作

| 状态 | 图 | 触发场景 | 备注 |
|---|---|---|---|
| 常态 | `Juzi` | 今日页常驻、空闲 | 唯一默认态 |
| 眨眼 | `JuziBlink` | 常态每 3–5 s 闪一次 | 120 ms，别更慢 |
| 开心 | `JuziHappy` | 答对 / 完成任务 / 打卡 | ^^ 眼 + 张嘴 |
| 困 | `JuziSleepy`（待画） | 深夜、复习超时 | 眼睛半闭 |
| 惊讶 | `JuziSurprised`（待画） | 连续答对 5 题、成就解锁 | 圆眼 + 小嘴 |

动作动画（待做）：`idle`（呼吸 + 眨眼，已出 APNG 预览）、`wave`（招手，用于首次引导）、`hop`（开心跳，用于完成页）。

## 四、文件清单

```
Design/Animals/01-juzi-orange-cat/
├── source/
│   ├── juzi.svg            主立绘（矢量源，改这里）
│   ├── juzi-blink.svg      眨眼
│   └── juzi-happy.svg      开心
├── render/                 Chrome 渲染结果（1024 透明 PNG）
│   ├── juzi-master.png
│   ├── juzi-blink.png
│   ├── juzi-happy.png
│   └── contact.png         三态对照图
└── export/
    ├── juzi-1024.png       贴纸大图
    ├── juzi.png            512 预览
    └── juzi-idle.apng      眨眼循环（3 帧 / 2.2 s）
```

App 内资源（已生成）：

```
BeanMan/Resources/Assets.xcassets/Animals/Juzi.imageset/
├── juzi.png      256 @1x
├── juzi@2x.png   512
├── juzi@3x.png   768
└── Contents.json
```

## 五、代码用法

```swift
// 静态立绘（自带眨眼动画）
AnimalView(animal: .juzi, size: 96)

// 指定表情、关掉动画
AnimalView(animal: .juzi, size: 64, expression: .happy, animated: false)

// 只要图，自己排版
Image(Animal.juzi.assetName)
    .resizable()
    .scaledToFit()
    .frame(width: 96, height: 96)

// 完成页的奖励动画
AnimalView(animal: .juzi, size: 160, expression: .happy)
    .phaseAnimator([false, true]) { view, up in
        view.offset(y: up ? -10 : 0)
    } animation: { _ in .spring(duration: 0.38, bounce: 0.5) }
```

## 六、文案（小豆说，橘子做表情）

| 时刻 | 小豆 | 橘子 |
|---|---|---|
| 今日有任务 | 「今天 12 个到期词，先啃三个？」 | 常态，轻晃尾巴 |
| 答对 | 「这个记住了。」 | 开心 |
| 答错 | 「没关系，它本来就不熟。」 | 常态，耳朵微垂 |
| 连续打卡 | 「第 7 天了，你有在坚持。」 | 开心 + 跳一下 |
| 深夜还在背 | 「太晚了，明天还有。」 | 困 |

## 七、改图流程

```bash
# 1. 改 SVG（source/juzi.svg）
# 2. 重新导出到 App 资源
python Scripts/animal_pipeline.py sheet \
  --svg Design/Animals/01-juzi-orange-cat/source/juzi.svg \
  --name Juzi --display "橘子" \
  --out BeanMan/Resources/Assets.xcassets/Animals \
  --sticker Design/Animals/01-juzi-orange-cat/export \
  --preview Design/Animals/01-juzi-orange-cat/export

# 3. 重出眨眼动画
python Scripts/animal_pipeline.py frames \
  --inputs Design/Animals/01-juzi-orange-cat/render/juzi-master.png,Design/Animals/01-juzi-orange-cat/render/juzi-blink.png,Design/Animals/01-juzi-orange-cat/render/juzi-master.png \
  --durations 1500,130,600 \
  --out Design/Animals/01-juzi-orange-cat/export/juzi-idle.apng
```

> SVG → PNG 用本机 Chrome 无头渲染（`Scripts/animal_pipeline.py` 里已封装），
> 换机器时确认 `CHROME_CANDIDATES` 里有对应路径。