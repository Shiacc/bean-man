# 豆卡单词 · BeanMan（iOS）

离线优先的背单词 App。SwiftUI + SwiftData，iOS 17+，无账号、无后端。

## 分支模型

| 分支 | 用途 | CI |
|---|---|---|
| **`dev`** | 唯一开发分支，所有提交都落这里 | push 即编译 + 单测（macOS runner） |
| `main` | 干净基线，只有一行 README | 不跑 |

发布走 tag（`v0.1.0` 这类），tag 会额外触发模拟器截图；需要截图时也可以在 Actions 页手动 Run workflow。

**仓库可见性**：测试期保持 **public**（macOS runner 免费不限分钟）；打 `v*` tag 时 `.github/workflows/repo-visibility.yml` 会自动把仓库转成 **private**，也可以手动 `powershell -ExecutionPolicy Bypass -File .\Scripts\repo_visibility.ps1 -Target private`。

```bash
git switch dev            # 日常都在 dev 上
git push origin dev       # 推 Gitee
git push github dev       # 推 GitHub（CI 在这里跑）
```

当前进度：**M1–M4 + F16–F21 已交付** —— 今日页（含跨夜刷新）、学习卡（四档 + 发音 + 手势 + 撤销 + 上滑跳过 + 完成页）、错词本（列表/卡片流）、测试（三种题型 + 拼写错写回）、词库（列表/详情/导入/导出/恢复内置库）、统计（7 天柱图 + **未来 7 天到期曲线** + **掌握度三段环**）、设置、本地提醒、气泡与引导、片尾字幕式弹幕复习（竖/横屏 + 黑白主题）、小豆分析（今日页洞察 + **设置里的分析面板**，带「去做/知道了」+ 7 天冷却）、买断内购与免费额度、成就里程碑（**单条里程碑可分享**）、**打卡分享图（1080×1350，本地渲染）**、生词本列表、**深色模式（19 个 token 亮/暗双值 + 对比度自检）**、**20 只小动物主立绘（AI 极简贴纸 v2，其中 8 只带表情变体）**、**16 张场景插画**。
待做：12 只动物的表情（happy / blink / sleepy）+ 6 张 surprised、内购沙盒验证、上架材料。动作帧按 `Docs/07` 的决策不做帧序列（呼吸、眨眼、挤压都用代码）。
代码已由 GitHub Actions 在 macOS runner 上编译 + 跑单测（最近一次全绿：`43039370581`，随时可用 `bash Scripts/ci_status.sh` 复核）。没有 Mac 也能看 CI 状态与失败细节——脚本会从 check-run annotation 和 run 页面 HTML 里把 `*.swift:行:列: error` 摘出来。

设计稿：Figma 文件 `app-design`，两个页面分工——
- **`beanman-ios`**（屏幕画板，14 行 / 41 屏，T-01-01 … T-14-01）：**14 行 / 41 屏总览** → `Design/beanman-ios-全流程-v7.png`（一行一个大功能：今日 2、学习卡 6、单词本 2、弹幕复习 6、小豆 4、词库 3、导入 2、生词本 2、测试 4、统计 1、设置 2、引导 4、付费 2、成就 1）
- **`beanman-components`**（规范页，根 frame `BeanMan · Design System` `123:13124`）：[Design/组件规范.md](Design/组件规范.md) — 18 个颜色 token、10 级字体阶梯、6 级圆角、5 档间距、6 组真组件、7 条使用规则；[对照图](Design/beanman-ios-DesignSystem-v1.png)
- 弹幕主题对照：[浅色](Design/beanman-ios-弹幕浅色-v1.png) · [退出方式](Design/beanman-ios-弹幕退出-v1.png) · 付费与成就：[付费墙](Design/beanman-ios-付费墙-v1.png) · [成就](Design/beanman-ios-成就-v1.png)

文档：
- [产品需求文档 PRD v0.4](Docs/02-PRD-豆卡单词-v0.4.md) — 功能规格、算法规格、手势规范、片尾字幕复习（黑白双主题 + 三种退出）、小豆推荐引擎、验收标准（AC-01…AC-73）、§17 功能完成度审计
- [阶段一：产品结构与数据模型](Docs/01-阶段1-产品结构与数据模型.md) — 分层、文件树、6 个 @Model、导入契约
- [小动物总谱](Design/Animals/00-小动物总谱.md) · [风格规范](Design/Animals/_风格规范.md)
- [**没有 Mac 怎么编译、怎么上线**](Docs/03-无Mac编译与上线.md) — GitHub Actions 编译/截图、API Key 签名、TestFlight、上架清单
- [**上架操作清单**](Docs/04-上架操作清单.md) — 从注册开发者账号到 TestFlight 内测的分步操作 + 中国区备案提醒
- [**真机测试**](Docs/05-真机测试.md) — 没有 Mac / 没有开发者账号时，怎么把 App 装进 iPhone（Sideloadly 自签 / TestFlight / Xcode 三条路）

---

## 一、在 Mac 上跑起来（约 5 分钟）

本机是 Windows，没有 Xcode，所以**代码从未编译过**。第一次编译可能需要修几处小错，属正常。

**方式 A（推荐，30 秒）：用 XcodeGen 生成工程**

```bash
brew install xcodegen
git clone git@gitee.com:zhuge-x/beanman.git
cd beanman
xcodegen generate          # 生成 BeanMan.xcodeproj
open BeanMan.xcodeproj     # ⌘R 运行，⌘U 测试
```

`BeanMan.xcodeproj` 是生成物，不进仓库；新增 `.swift` 文件不用改工程，Windows 侧也能加。
若想改用 Xcode 图形界面建工程，走方式 B。

**方式 B：手工建工程**

1. Xcode → File → New → Project → iOS → **App**
   - Product Name：`BeanMan`
   - Interface：**SwiftUI**
   - Language：**Swift**
   - Storage：**SwiftData**
   - 取消勾选 "Include Tests"（我们用自己的测试文件）
2. 删掉模板生成的 `BeanManApp.swift`、`ContentView.swift`、`BeanMan/` 里的 Assets 之外的多余文件（保留 `Assets.xcassets`）。
3. 把本目录下的 `BeanMan/` 整个文件夹拖进工程导航栏：
   - 勾选 **Copy items if needed** ❌ 不需要（文件已在工程目录里，直接引用更省事）
   - 勾选 **Create groups**
   - 勾选 target `BeanMan`
4. 新建单元测试 target：File → New → Target → **Unit Testing Bundle**，名字填 `BeanManTests`，然后把本目录的 `BeanManTests/` 文件夹拖进去。
5. 构建设置检查：
   - `iOS Deployment Target` ≥ **17.0**
   - `Swift Language Version` = **Swift 5**（切片期先用 5，代码里已经把 `@MainActor` 标好；等全功能齐了再切 6）
   - `Swift Concurrency Checking` = `Minimal`
6. ⌘R 运行。⌘U 跑测试。

> 真机跑需要签名（Signing & Capabilities → Team 选自己的 Apple ID）。

---

## 二、文件地图

```
BeanMan/
  App/
    BeanManApp.swift         @main，建 SwiftData 容器
    RootView.swift           自定义底部 TabBar
    AppRouter.swift          标签切换路由（今日页跳词库用）
  Models/
    Models.swift             6 个 @Model：Deck / Word / ReviewState / StudyRecord / StudySession / AppSettings
  Persistence/
    BeanManStore.swift       容器、bootstrap、Preview 容器、Demo 进度
    AppSettingsStore.swift   设置的哨兵单例读写
    SeedLibrary.swift        24 个自写示例词（无版权风险）
  Services/
    SRS/SRSAlgorithm.swift   简化 SM-2，纯函数
    Study/StudyRepository.swift  队列生成 / 今日计数 / 评分写回 / 打卡日集合
    WrongBook/WrongBookService.swift  错词派生规则 / 快照 / 专项复习队列 / 移出与恢复
    ImportExport/CSVParser.swift      手写 CSV 解析（BOM / CRLF / 引号 / 字段内换行）
    ImportExport/DeckImporter.swift   表头别名、逐行校验、去重、建词库
    ImportExport/BackupService.swift  JSON 备份导出 / 恢复 / 重置进度
    Notification/NotificationService.swift  每日本地提醒（固定 identifier，先删后加）
    Speech/SpeechService.swift   AVSpeechSynthesizer 封装
    Stats/StatsService.swift     统计快照：打卡 / 7 天数据 / 掌握度 / 正确率
    Stats/ForecastService.swift  未来 7 天到期预测（逾期压今天、挂起不计、窗口外不借数字）
    Share/ShareCardService.swift 打卡分享图：文案拼装 + 1080×1350 渲染 + 临时文件
    Quiz/QuizService.swift       抽题（4:3:3）、判分、可复现随机源
  Support/
    DayKey.swift             yyyy-MM-dd、startOfDay、连续打卡
    DueText.swift            「逾期 2 天」「明天」「11 月 9 日」这类相对时间
    Enums.swift              Rating / StudyPhase / StudyKind / VoiceAccent
  DesignSystem/
    Theme.swift              颜色 / 圆角 / 间距 / 字号（取自 Figma 变量集合）
    Components/Components.swift  小豆卡、统计卡、按钮、进度条、四档评分、快捷行
    Assistant/Xiaodou.swift  小豆文案层（纯本地，不联网）
    Animals/Animal.swift     20 只小动物：名字 / 用途 / 配色 / 素材名
    Animals/AnimalView.swift 立绘 + 缺图占位 + 眨眼呼吸动画
    Illustrations/SceneArt.swift 场景插画（引导 / 空状态 / 庆祝，保留米色底）
    Bubbles/SpeechBubble.swift   对话气泡（5 种语气 × 4 个尾巴方向）
    Bubbles/CompanionBubble.swift 小动物 + 气泡的组合
    Hints/HintCenter.swift   引导提示的调度与持久化（纯逻辑可单测）
    Hints/HintOverlay.swift  挖洞蒙层 + 脉冲环 + 说明气泡
  ViewModels/
    TodayViewModel.swift     今日页数字
    StudyViewModel.swift     学习会话状态机
    WrongBookViewModel.swift 错词本的筛选 / 搜索 / 移出恢复
    StatsViewModel.swift     统计页快照
    QuizViewModel.swift      测试流程（选题 / 判分 / 成绩）
  Views/
    Onboarding/OnboardingView.swift 首启引导：每日计划 / 提醒 / 口音 / 词库（4 步）
    Tabs/TodayView.swift           今日页（Figma T-01-01 / T-01-02）
    Study/StudyView.swift          学习卡正面/背面（T-02-01 / T-02-02）
    Study/StudySummaryView.swift   学习完成（T-02-03）
    WrongBook/WrongBookView.swift  错词本列表（筛选 / 搜索 / 滑动移出 / 空状态）
    WrongBook/WordDetailView.swift 词条详情：释义、例句、学习状态、移出/放回
    Deck/DeckListView.swift        词库列表：设为当前 / 删除 / 进入详情
    Deck/DeckDetailView.swift      词表、搜索、删词、设为当前、词条速览
    Deck/ImportView.swift          导入：选 CSV 文件或粘贴文本，显示逐行跳过原因
    Tabs/StatsView.swift           统计页：打卡 / 掌握度 / 7 天堆叠柱状图
    Quiz/QuizView.swift            测试页：看词选义 / 看义拼词 / 听音选义
    Danmaku/DanmakuReviewView.swift 弹幕复习：片尾字幕式滚动，点按暂停、右滑退出
    WrongBook/WrongBookCardsView.swift 单词本卡片流：轻点下一个 / 左滑移出 / 右滑收藏
    Settings/SettingsView.swift    计划 / 提醒 / 发音 / 导出恢复 / 重置 / 关于
    Settings/PaywallView.swift     买断付费墙（只在到额度或主动升级时出现）
    Settings/InsightPanelView.swift 小豆分析面板：四时段正确率 / 常错 Top3 / 规则说明
    Achievements/AchievementsView.swift 成就墙 + 达成时的全屏庆祝
    Share/ShareCardView.swift      打卡分享卡版式 + 预览/分享面板（今日页长按统计块）
    Debug/DesignGalleryView.swift  设计验收页：气泡 / 动物 / 引导动画 / 分享卡 / 颜色 token / 素材自检
  Services/
    Purchase/TierGate.swift        免费额度闸门（1 库 / 500 词 / 每日 20 新词）
    Purchase/PurchaseService.swift StoreKit 2 买断、恢复购买、权益缓存
    Achievements/AchievementCenter.swift 8 个本地里程碑
    Insights/InsightEngine.swift   最佳时段 / 积压 / 连续风险 / 常错词 + 3 个推荐词
    Insights/InsightCenter.swift   洞察的「知道了」冷却（7 天）与每日条数
  Resources/
    Assets.xcassets/Animals/…     20 只主立绘（AI 极简贴纸 v2，256/512/768，PNG8 共约 0.6MB）
    Assets.xcassets/Animals/…*Happy|Blink|Sleepy  表情变体（512 单档）
    Assets.xcassets/Illustrations/… 16 张场景插画（引导 / 空状态 / 庆祝，1024 单档）
BeanManTests/
  SRSAlgorithmTests.swift    算法 7 组断言
  StudyRepositoryTests.swift 队列 / 限额 / 写回 / 打卡
  HintCenterTests.swift      提示只显示一次 / 冷却 / 抢占 / 重置
  WrongBookServiceTests.swift 错词派生规则 / 移出恢复 / 专项队列排序
  ImportExportTests.swift    CSV 解析 / 列名别名 / 去重 / 无效行 / 备份往返 / 重置
  ProFeatureTests.swift      额度闸门 / 洞察推荐 / 成就解锁
  DanmakuReviewViewModelTests.swift 弹幕时钟 / 暂停 / 循环 / 换速 / 主题
  ForecastServiceTests.swift 到期预测：逾期压今天 / 挂起不计 / 窗口外 / 最忙一天 / 标签
  ShareCardTests.swift       分享图文案与尺寸（1080×1350）
  StatsServiceTests.swift    到期预测与「今日待复习」同源、掌握度三段切分
  ThemeContrastTests.swift   深色模式：每个 token 都有暗色值、正文 7:1 / 次要 4.5:1
  StudyViewModelSkipTests.swift 跳过不写记录 / 跳到最后会结束 / 跳过之后仍能正常评分
  InsightCenterTests.swift   洞察 dismiss 7 天冷却 / 每天最多 3 条 / 重启后仍然记得
  TodayViewModelTests.swift  跨夜回到前台：日期与今日已学要跟着换（AC-08）
Design/
  beanman-ios-今日与学习卡-v1.png  Figma 稿截图
  Preview/bubbles.{html,png}       气泡与引导的像素对照图（HTML 1:1 复刻 SwiftUI 数值）
  Animals/                         20 只动物总谱（v2 画风说明）、01–20 源文件、大合照 contact-sheet-v2.png
Scripts/
  animal_pipeline.py         SVG → PNG → imageset 的自动化流水线（v1 矢量风格）
  ai_cutout.py / ai_batch.py AI 出图抠白底 → imageset（v2 风格，当前在用）
  ai_check_edges.py          橙/深/米三底检查抠图白边与小尺寸可读性
  haoee_gemini_relay.py      把插件的 x-goog-api-key 转成 Bearer，转发到 haoee 网关
  sync.sh / sync.ps1         多设备同步
```

---

## 三、这一版能验证什么（对着 Figma 稿点）

- [ ] 首启自动装好示例词库，今日页显示「N 个待复习 / N 个新词」
- [ ] 点「开始学习」进入全屏卡片，正面只有单词 + 音标 + 喇叭
- [ ] 点卡片翻面（3D 翻转），出现词性 / 释义 / 例句 / 例句翻译 / 备注
- [ ] 翻面后点四个按钮之一，自动进下一张，进度条前进
- [ ] 关掉 App 重开，进度还在（今日已学数量 +1、待复习数量 -1）
- [ ] 首次安装启动会走 4 步引导：选每日新词 / 复习上限 → 提醒时间（会请求通知权限）→ 美音英音试听 → 词库说明；点「开始使用」进入今日页
- [ ] 引导完成后杀掉 App 重开，不会再弹引导（设置里改了计划仍然生效）
- [ ] 全部学完出现完成页：正确率 / 用时 / 连续打卡 + 小豆的一句话
- [ ] 深色模式下卡片、文字、按钮都正常
- [ ] 首次进今日页会弹一次引导（挖洞 + 脉冲环 + 说明），点「知道了」后不再出现
- [ ] 设置 → 设计验收：气泡 5 种语气、4 个尾巴方向、20 只动物表情矩阵、16 张场景插画、分享卡两种（含「渲染并检查尺寸」）、**19 个颜色 token 色板**、引导动画演示、素材自检
- [ ] 学习时点「不认识 / 模糊」→ 今日页「错词本 N 个」+1；点进去能按「待复习 / 全部 / 已移出」筛选、搜索、滑动移出、点开详情看学习状态
- [ ] 错词本底部「复习这 N 个错词」进入专项复习，完成页标题是「这轮错词过完了」
- [ ] 词库页能看到示例词库和词数，点进去能搜「abandon」、滑动删词、右上角「设为当前」
- [ ] 词库页右上角导入：粘贴一段 `word,meaning` 两列的表格，点「开始导入」后提示「导入 N 个」
- [ ] 导入时混入空单词 / 空释义的行，报告里会逐行列出「第 N 行：……」
- [ ] 设置 → 导出备份会存出一个 JSON；改动几个词后再「从备份恢复」，提示跳过已存在的词库
- [ ] 设置 → 重置学习进度：勾选确认后，今日页待复习与新词回到初始额度
- [ ] 今日页「测试一下」：学过 4 个词后能出题，三种题型轮流出现，拼写题输入后回车判分，成绩页给正确率环
- [ ] 统计页：打卡天数、今日已学 / 待复习、累计词数、正确率、掌握度，7 天柱状图能区分新词与复习
- [ ] 今日页「词库」那行能跳到词库标签（不是死按钮）
- [ ] 学习卡左滑 = 不认识、右滑 = 认识（没翻面时右滑只翻面）、长按朗读并收藏星星
- [ ] 评分后底部出现「撤销上一张」，撤销后回到那张卡、今日数字回退
- [ ] 测试里拼写题故意拼错：成绩页正确率下降，且该词出现在错词本里
- [ ] 今日页「弹幕复习」：整屏匀速向上滚，每个词两行（单词+音标 / 词性+释义）
- [ ] 弹幕复习轻点任意处暂停，再点继续；右上角换深浅主题；右滑一下退出，再进还在原位置
- [ ] 横屏打开弹幕复习：每个词压成一行，行距更紧
- [ ] 错词本左上角「卡片浏览」：轻点下一个、左滑移出、右滑收藏
- [ ] 今日页「小豆的分析」：有足够数据时给出时段洞察，并列出 3 个推荐词
- [ ] 开始学习后，推荐词出现在队列末尾（不计入每日新词额度），学习卡正面有「小豆推荐」chip
- [ ] 今日页任务卡在有小豆推荐时显示「+N 小豆推荐」
- [ ] 设置 → 重置学习进度：必须手打「重置」两个字才会执行，打错只提示、数据不动
- [ ] 设置 → 升级：免费额度文案与实际一致；点「解锁全部功能」弹出付费墙
- [ ] 成就墙显示 8 个里程碑，首次达到时全屏庆祝一次，之后不再弹
- [ ] 统计页「未来 7 天到期」曲线：7 个点、今天高亮；逾期词算进今天，挂起词不计
- [ ] 统计页「掌握度」是未学 / 学习中 / 已掌握三段环，三个数字加起来等于总词数
- [ ] 系统切到深色外观：今日 / 统计 / 设置 / 学习卡的底色、文字、卡片都跟着变（不是白底黑字）
- [ ] 学习卡轻点已翻面 → 下一张（不评分）；上滑也能跳过；跳过的词不进错词本、不能撤销
- [ ] 小豆分析每条都有「去做 / 知道了」；点「知道了」7 天内不再出现，时段洞察的「去做」落在设置页
- [ ] 设置 → 小豆分析：四个时段正确率柱图、常错 Top3、规则说明；「知道了」后那条显示「已收起 · 7 天后再提」
- [ ] 无词库时今日页按钮是「去词库选一个」，点了切到词库标签
- [ ] 跨夜回到前台（或放着过 0 点）：日期、今日已学、待复习、连续打卡都会刷新
- [ ] 打开「减少动态效果」：翻面变成淡入淡出，没有 3D 翻转
- [ ] 今日页长按三连统计块（或点「分享打卡图」）→ 出预览 → 分享出去的图是 1080 × 1350
- [ ] 成就墙里已解锁的卡片右上角有分享按钮 → 生成该条里程碑的分享卡
- [ ] 免费额度用满（建第 2 个词库 / 导入超 500 词）时弹付费墙而不是直接报错

---

## 三·五、气泡与引导怎么验证

代码在 `DesignSystem/Bubbles/` 与 `DesignSystem/Hints/`，三层验证：

1. **看**：Xcode 里打开 `SpeechBubble.swift` / `CompanionBubble.swift` / `HintOverlay.swift`，右侧 Canvas 有三个 `#Preview`，不用跑模拟器。
2. **点**：运行 App → 底部「设置」→ **设计验收**。气泡、动物、引导全部可点，「重置所有提示记录」可让引导重新出现（引导本身用的是持久化记录，重置才会再弹）。
3. **测**：⌘U 跑 `BeanManTests/HintCenterTests.swift`，覆盖「只显示一次 / 冷却 / 高优先级抢占 / dismiss 后可取下一个 / 重置后可再显示 / 每条 id 都有文案」。

不想开 Xcode 也能先看长相：`Design/Preview/bubbles.png` 是用 HTML 按 SwiftUI 同一套数值（圆角 18、尾巴 16×16 转 45°、蒙层 42%、挖洞外扩 8、环 2px）1:1 复刻出来的对照图。

**引导的规则**（改行为先看这里）

- 每个提示有一条 `HintRequest`：`id` + `priority` + `onceOnly` + `cooldown`；
- 显示过就写进 `UserDefaults`（`hint.seen.v1` / `hint.lastShown.v1`），重装才清空；
- 高优先级正在显示时，低优先级请求直接让路（`skipBusy`），不会排队、不会打断；
- 目标位置靠 `.captureFrame(HintID.xxx)` 上报全局坐标，蒙层内部换算成本地坐标再挖洞——所以挂在 ScrollView 里也不会偏一个安全区。

---

## 四、多设备同步

远程仓库：`git@gitee.com:zhuge-x/beanman.git`（私有）。**唯一真相源是远程，两台设备各留一份工作副本。**

| 设备 | 角色 | git |
|---|---|---|
| Mac | 编译 / 跑模拟器 / 跑测试 | 原生 git |
| Windows（这台） | 写代码、设计稿、AI 工作台 | 只有 WSL 里的 git |

```bash
# Mac：一天的开头和结尾
git pull --rebase
git add -A && git commit -m "feat: 词库页" && git push

# Windows：一条命令搞定（内部转给 WSL 的 git）
.\Scripts\sync.ps1 "feat: 今日页"
```

`Scripts/sync.sh` 做三件事：`pull --rebase --autostash` → 有改动就提交 → `push`。
不带参数时提交信息自动是 `chore: 同步 <时间>`。

**几条硬规矩**

- 工作副本**不要**放进 iCloud / OneDrive / 坚果云 —— 云客户端半写入 `.git` 会让仓库损坏；
- 两台设备**不要同时**改同一个 Xcode 工程（用了 `project.yml` 之后这条基本不成立了）；
- 换行已由 `.gitattributes` 统一成 LF，别手动改；
- 提交前 `git status` 看一眼，`Secrets/`、`*.p8`、`*.mobileprovision` 已被 `.gitignore` 挡住。

**密钥跨设备**：签名证书走 1Password / 加密盘，不进仓库；若用 sops 加密存放，age 私钥同样放 1Password。

---

## 五、没有 Mac 怎么编译、怎么上线

这台机器是 Windows，**编不了 iOS**（`xcodebuild` 只有 macOS 版）。三条路，详见 [Docs/03-无Mac编译与上线.md](Docs/03-无Mac编译与上线.md)：

| 方案 | 能做什么 | 成本 |
|---|---|---|
| **GitHub Actions（主力）** | 编译、单测、模拟器截图、打 IPA、传 TestFlight | 公开仓库免费；私有仓库约 200 分钟/月 |
| 云 Mac（按小时） | 实时预览、断点、调签名 | ¥5–15/小时 |
| 买 Mac mini | 什么都能做 | ¥2000–3500 一次性 |

**第一步（今天就能做）：把仓库镜像到 GitHub，让 CI 把编译错误吐出来。**

```bash
git remote add github git@github.com:shiack/beanman.git
git push -u github main
```

之后每次 push 会自动跑 `.github/workflows/ios-build.yml`：生成工程 → 编译 → 跑单测 → 装进模拟器截一张今日页 → 上传 artifact。
Actions 页面的 **Artifacts → screenshots** 就是不用 Mac 也能看到的界面。

签名和上传也不用 Mac：在 App Store Connect 建一个 **API Key**（`.p8`），把 4 个值放进 GitHub Secrets，
手动跑 `.github/workflows/release-testflight.yml` 就能出 IPA 并推到 **TestFlight**——iPhone 上装 TestFlight 就能真机试用，这是「没有 Mac 的真机调试渠道」。

---

## 六、已知待办

**素材类**
- 动物表情：20 只主立绘齐了，表情只出了 21 个图集（happy 8 / blink 5 / sleepy 8 / surprised 0）。还缺约 39 张 + 6 张 surprised，按 [Docs/07](Docs/07-动效与素材清单.md) 的流水线用 AI 出（以主立绘为参考、只改眼睛和嘴）。缺的一侧 `AnimalView` 自动回落主立绘，不影响功能。
- 动作帧：按 `Docs/07` 的决策**不做帧序列**——呼吸用 `scaleEffect`、眨眼用切图、跳/挤压用位移+缩放，改参数不用重出图。
- 深色模式：token 和对比度有单测守着，但「逐页好不好看」仍需人眼过一遍（CI 现在会多拍一张深色今日页）。

**账号 / 真机类**
- 内购还没在真机 / 沙盒里跑过：需要在 App Store Connect 建好 `com.yourname.beanman.pro` 才能验。
- 本地提醒、通知授权文案、GB18030 导入样本、听音题语音包：都要真机复核。

**环境**
- 图片生成依赖本机的 `Scripts/haoee_gemini_relay.py`（计划任务 `haoee-gemini-relay`，端口 8791）；换机器要重新配。
- 界面里已接入 9 只：橘子（首页气泡 / 付费墙）、雪球（错词本空态）、布丁（完成页庆祝）、泡泡（测试空态 / 弹幕空态）、芝麻（生词本空态）、咕噜（词库空态）、棉花、团子 / 云朵 / 小柚（仅 Design Gallery 预览）。
- iCloud 同步 / FSRS / Anki 导入（PRD 里明确不做，留到 1.x 之后再说）。