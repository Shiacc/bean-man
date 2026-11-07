# 豆卡单词 · BeanMan（iOS）

离线优先的背单词 App。SwiftUI + SwiftData，iOS 17+，无账号、无后端。

当前进度：**垂直切片 v1 —— 今日页 + 学习卡**（能在模拟器里完整跑：看今日任务 → 翻卡 → 四档评分 → 写回复习状态 → 完成页）。
词库 / 统计 / 设置三个 Tab 是占位页，第二阶段实现。

设计稿：Figma 文件 `app-design` → 页面 `beanman-ios`；截图见 `Design/beanman-ios-今日与学习卡-v1.png`。

---

## 一、在 Mac 上跑起来（约 5 分钟）

本机是 Windows，没有 Xcode，所以**代码从未编译过**。第一次编译可能需要修几处小错，属正常。

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
    RootView.swift           自定义底部 TabBar + 三个占位页
  Models/
    Models.swift             6 个 @Model：Deck / Word / ReviewState / StudyRecord / StudySession / AppSettings
  Persistence/
    BeanManStore.swift       容器、bootstrap、Preview 容器、Demo 进度
    AppSettingsStore.swift   设置的哨兵单例读写
    SeedLibrary.swift        24 个自写示例词（无版权风险）
  Services/
    SRS/SRSAlgorithm.swift   简化 SM-2，纯函数
    Study/StudyRepository.swift  队列生成 / 今日计数 / 评分写回 / 打卡日集合
    Speech/SpeechService.swift   AVSpeechSynthesizer 封装
  Support/
    DayKey.swift             yyyy-MM-dd、startOfDay、连续打卡
    Enums.swift              Rating / StudyPhase / VoiceAccent
  DesignSystem/
    Theme.swift              颜色 / 圆角 / 间距 / 字号（取自 Figma 变量集合）
    Components/Components.swift  小豆卡、统计卡、按钮、进度条、四档评分、快捷行
    Assistant/Xiaodou.swift  小豆文案层（纯本地，不联网）
  ViewModels/
    TodayViewModel.swift     今日页数字
    StudyViewModel.swift     学习会话状态机
  Views/
    Tabs/TodayView.swift           今日页（Figma T-01-01 / T-01-02）
    Study/StudyView.swift          学习卡正面/背面（T-02-01 / T-02-02）
    Study/StudySummaryView.swift   学习完成（T-02-03）
BeanManTests/
  SRSAlgorithmTests.swift    算法 7 组断言
  StudyRepositoryTests.swift 队列 / 限额 / 写回 / 打卡
```

---

## 三、这一版能验证什么（对着 Figma 稿点）

- [ ] 首启自动装好示例词库，今日页显示「N 个待复习 / N 个新词」
- [ ] 点「开始学习」进入全屏卡片，正面只有单词 + 音标 + 喇叭
- [ ] 点卡片翻面（3D 翻转），出现词性 / 释义 / 例句 / 例句翻译 / 备注
- [ ] 翻面后点四个按钮之一，自动进下一张，进度条前进
- [ ] 关掉 App 重开，进度还在（今日已学数量 +1、待复习数量 -1）
- [ ] 全部学完出现完成页：正确率 / 用时 / 连续打卡 + 小豆的一句话
- [ ] 深色模式下卡片、文字、按钮都正常

---

## 四、已知待办

- 词库页（导入 CSV/JSON、搜索、导出）、统计页（7 天柱状图）、设置页（计划/提醒/发音/数据管理）
- 本地通知（UNUserNotificationCenter，`Info.plist` 不需要额外权限 key，但首次要请求授权）
- 生词本 / 错词本落库（现在只有 `isFavorite` 字段，还没有错词自动收集逻辑）
- 测试题（三种题型）
- 首次引导页