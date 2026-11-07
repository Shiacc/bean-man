# 豆卡单词 · BeanMan（iOS）

离线优先的背单词 App。SwiftUI + SwiftData，iOS 17+，无账号、无后端。

当前进度：**垂直切片 v1 —— 今日页 + 学习卡**（能在模拟器里完整跑：看今日任务 → 翻卡 → 四档评分 → 写回复习状态 → 完成页）。
词库 / 统计 / 设置三个 Tab 是占位页，第二阶段实现。

设计稿：Figma 文件 `app-design` → 页面 `beanman-ios`；截图见 `Design/beanman-ios-今日与学习卡-v1.png`。

文档：
- [产品需求文档 PRD v0.2](Docs/02-PRD-豆卡单词-v0.2.md) — 功能规格、算法规格、交互规范、验收标准（AC-01…AC-52）
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
    Settings/SettingsView.swift    计划 / 提醒 / 发音 / 导出恢复 / 重置 / 关于
    Debug/DesignGalleryView.swift  设计验收页：气泡 / 动物 / 引导动画 / 素材自检
  Resources/
    Assets.xcassets/Animals/…     动物图（Juzi.imageset 三档尺寸）
BeanManTests/
  SRSAlgorithmTests.swift    算法 7 组断言
  StudyRepositoryTests.swift 队列 / 限额 / 写回 / 打卡
  HintCenterTests.swift      提示只显示一次 / 冷却 / 抢占 / 重置
  WrongBookServiceTests.swift 错词派生规则 / 移出恢复 / 专项队列排序
  ImportExportTests.swift    CSV 解析 / 列名别名 / 去重 / 无效行 / 备份往返 / 重置
Design/
  beanman-ios-今日与学习卡-v1.png  Figma 稿截图
  Preview/bubbles.{html,png}       气泡与引导的像素对照图（HTML 1:1 复刻 SwiftUI 数值）
  Animals/                         20 只动物总谱、风格规范、01 橘子的源文件与导出
Scripts/
  animal_pipeline.py         SVG → PNG → imageset 的自动化流水线
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
- [ ] 设置 → 设计验收：气泡 5 种语气、4 个尾巴方向、20 只动物表情矩阵、引导动画演示、素材自检
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

- 生词本「手动收藏」入口（`Word.isFavorite` 字段在，还没有列表页；错词本已做）
- 其余 19 只小动物（02 团子 … 20 小柚）的立绘、表情与 imageset
- 学习完成页的小动物庆祝动画（现在只有勾选图标 + 小豆一句话）
- 测试页还没写单测（`QuizService` 是纯函数，补 `QuizServiceTests` 成本很低）
- iCloud 同步 / FSRS / Anki 导入（PRD 里明确不做，留到 1.x 之后再说）