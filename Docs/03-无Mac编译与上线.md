# 没有 Mac，怎么编译、试用、上线

> 结论先说：**编译不用 Mac（GitHub Actions 的 macOS 机器），签名和上传也不用 Mac（App Store Connect API Key），只有「改 UI 时想实时预览」和「上线前截屏/调签名」这两件事，租一台云 Mac 按小时用最划算。**

---

## 0. 三条路怎么选

| 方案 | 能做什么 | 不能做什么 | 成本 | 适合 |
|---|---|---|---|---|
| **A. GitHub Actions（macOS runner）** | 编译、跑单测、跑模拟器截图、打包 IPA、上传 TestFlight | 不能实时预览 UI、不能点着调试 | 公开仓库免费；私有仓库约 200 分钟/月（免费额度） | 日常主力 |
| **B. 云 Mac（按小时租）** | 全套 Xcode：Canvas 预览、模拟器、断点、截图、签名排错 | 按小时计费、网络延迟 | 约 ¥5–15/小时 | 改 UI 的那几天、上线前 |
| **C. 买一台 Mac mini** | 什么都能做，随时可用 | 一次性支出 | M4 mini 约 ¥3500 起（二手 M1 约 ¥2000） | 长期主力开发 |

**推荐组合**：日常 push 到 GitHub 让 A 编译 + 出截图；每 1–2 周租 4 小时 B 集中调 UI 和签名；真要做上一年再考虑 C。

---

## 1. 为什么必须有 macOS

iOS App 的工具链是闭源的，且只在 macOS 上分发：

- `xcodebuild`（编译器驱动）、`actool`（资源编译）、`ibtool`、`simctl`（模拟器）只有 macOS 版；
- 链接阶段需要 Apple 的 SDK 与 `ld`，Linux/Windows 上没有合法可用的替代；
- 签名的 `codesign` 同样是 macOS 独占。

例外与误区：

- ❌ 「Windows 上装个 Xcode 虚拟机」——违反 Apple 许可协议（macOS 只能跑在 Apple 硬件上），且没有虚拟化支持。
- ❌ 「用 Docker 跑 macOS」——同样受许可限制，且需要 KVM 嵌套虚拟化。
- ✅ 「CI 上跑 macOS 虚拟机」——GitHub/Microsoft 是 Apple 授权的云服务商，合法。

---

## 2. 方案 A：GitHub Actions

### 2.1 前置：把仓库镜像到 GitHub

Gitee 没有 macOS runner。现在的仓库在 Gitee，需要同步一份到 GitHub（账号 `shiack`，SSH 已验证可用）。

```bash
# 在 WSL 里，仓库根目录
git remote add github git@github.com:shiack/beanman.git
git push -u github main
```

之后每次 `git push` 可以同时推两边：

```bash
git remote set-url --add --push origin git@gitee.com:zhuge-x/beanman.git
git remote set-url --add --push origin git@github.com:shiack/beanman.git
git push          # 一次推两个远端
```

**公开还是私有？** 这直接决定要花多少钱：

| | 公开仓库 | 私有仓库 |
|---|---|---|
| macOS runner | **免费，不限分钟** | 走免费额度，macOS 消耗按 **10 倍**计 |
| 免费额度 | — | 2,000 分钟/月 → 实际约 **200 分钟 macOS** |
| 一次完整 build+test | 约 4–8 分钟 | 同上，但记账 ×10 |

一个 8 分钟的 job 在私有仓库要记 80 分钟额度，一个月只能跑 25 次左右。**建议先用公开仓库**（代码是个人项目，没有敏感信息；证书和密码永远不进仓库，走 Secrets）。

### 2.2 现有工作流做了什么

`.github/workflows/ios-build.yml`：

1. `macos-15` 起一台 macOS（自带 Xcode 16.x）；
2. `brew install xcodegen xcbeautify` + `xcodegen generate` 生成 `.xcodeproj`；
3. 用 python 从 `xcrun simctl list devices available -j` 挑一个可用模拟器 UDID；
4. `xcodebuild build`（`generic/platform=iOS Simulator`，`CODE_SIGNING_ALLOWED=NO`）；
5. `xcodebuild test`（跑到具体模拟器上）；
6. 上传 `.xcresult` 作为 artifact。

**这一步的价值**：它回答「代码到底能不能编译」。我们所有 Swift 都是在这台机器上第一次被编译器看过的，报错会直接出现在 Actions 日志里。

### 2.3 怎么「看到」界面（模拟器截图）

CI 里没有屏幕，但可以截图：编译出模拟器版 `.app` → 装进模拟器 → 启动 → `simctl io screenshot` → 上传 artifact。工作流里已经加了 `screenshots` job（见 `.github/workflows/ios-build.yml`），产物在 Actions 页面的 Artifacts 里下载 `screenshots.zip`。

```bash
UDID=...                       # 上一步挑出来的
xcrun simctl boot "$UDID" || true
xcrun simctl bootstatus "$UDID" -b
xcrun simctl install "$UDID" build/DerivedData/Build/Products/Debug-iphonesimulator/BeanMan.app
xcrun simctl launch "$UDID" com.yourname.beanman
sleep 4
xcrun simctl io "$UDID" screenshot shots/today.png
```

局限与解法：`-startTab` 直接落到某个标签，`-openScreen` 直接打开某个全屏页/sheet——不需要 UI Test：

```bash
# 四个标签
xcrun simctl launch "$UDID" com.yourname.beanman -skipOnboarding -startTab stats
# 今日页上的全屏页（study / wrongBook / quiz / achievements / favorites / danmaku / share）
xcrun simctl launch "$UDID" com.yourname.beanman -skipOnboarding -openScreen study
```

`screenshots` job 现在就是这么批量拍的：**4 个标签 × 亮/暗 + 3 个全屏页 × 亮/暗 = 14 张**，
文件名 `tab-<名字>-<light|dark>.png` / `screen-<名字>-<light|dark>.png`。
深色模式要不要返工，看这一份 artifact 就够了（`ThemeContrastTests` 只管对比度数值，管不了好不好看）。

### 2.4 失败了怎么看

1. Actions → 点失败的 run → 展开红色步骤；
2. 搜索 `error:`（`xcbeautify` 会把它高亮成 `❌`）；
3. 常见几类：
   - `cannot find 'X' in scope` —— 文件没进 target（检查 `project.yml` 的 `sources`，新目录要重新 `xcodegen generate`，CI 每次都重新生成，所以本地漏加目录不影响 CI）；
   - `Call to main actor-isolated ... in a synchronous nonisolated context` —— 并发隔离，给 View/ViewModel 加 `@MainActor`；
   - `The operation couldn't be completed. Failed to locate any simulator` —— 模拟器 runtime 没装，改用 `macos-15` 或指定 `-destination 'platform=iOS Simulator,name=iPhone 16'`；
   - `Signing for "BeanMan" requires a development team` —— 模拟器构建忘了加 `CODE_SIGNING_ALLOWED=NO`。

**不想开浏览器 / 在另一台机器上时**：失败步骤（`摘出编译错误`）会把每条 `*.swift:行:列: error:` 再发成 check-run annotation。公开仓库下 annotation 不需要 token 就能读，而作业日志（`/actions/jobs/<id>/logs`）要 admin 权限、读不到：

```bash
SHA=$(git rev-parse HEAD)
curl -s "https://api.github.com/repos/Shiacc/bean-man/commits/$SHA/check-runs" \
  | python3 -c "import json,sys; [print(c['id'], c['conclusion'], c['annotations_url']) for c in json.load(sys.stdin)['check_runs']]"
# 拿上一步的 annotations_url
curl -s "<annotations_url>" | python3 -c "import json,sys; [print(a['annotation_level'], a['path'], a['start_line'], a['message'][:200]) for a in json.load(sys.stdin)]"
```

单测失败的断言也会走这条通道——XCTest 的失败行同样是 `BeanManTests/Foo.swift:42: error: ...` 格式，会被同一个 grep 捞到。

### 2.5 分钟数与排队

- 公开仓库基本秒起；私有仓库高峰期可能排队。
- 一次完整跑（brew 装工具 + 生成 + build + test）约 5–9 分钟，其中 `brew install` 占 1–2 分钟（可以缓存）。
- 想省时间：把 `brew install` 换成 `brew bundle` + `actions/cache`，或者直接下载 xcodegen 预编译二进制。

---

## 3. 方案 B：云 Mac（什么时候真的需要）

CI 能告诉你「编译过不过」，但告诉不了你「这个间距是不是丑」。

| 服务 | 形态 | 大致价格 | 备注 |
|---|---|---|---|
| MacinCloud | 按小时/按天租 | $1/小时起 | 有 Windows 客户端（RDP），上手最快 |
| MacStadium | 按月租独立 Mac mini | $79/月起 | 稳定，适合长期 |
| Scaleway / AWS EC2 mac | 按小时，ARM Mac | 约 $0.10–0.65/小时 | 需要信用卡 + 配额申请，开通慢 |
| 淘宝/闲鱼「云 Mac」 | 按天 | ¥30–80/天 | 便宜，但注意数据安全，别登主 Apple ID |

**用云 Mac 时只做四件事**（4 小时够）：

1. `xcodegen generate` + ⌘B，把编译错误一次修完（比在 CI 里盲改快 10 倍）；
2. Xcode Canvas 看 SwiftUI 预览，调间距/字号/颜色；
3. 真机或模拟器跑一遍主流程，录屏给用户看；
4. 截 App Store 截图（6.9 英寸模拟器，⌘S）。

> 数据安全：云 Mac 上不要保存 Apple ID 密码；用完在 `appleid.apple.com` 里撤销该设备的信任；签名证书不要导出到云机器上（用 CI 的 API Key 方案）。

---

## 4. 方案 C：买一台 Mac mini

如果这个项目要做一年以上，买比租划算：

- Mac mini M4（16GB/256GB）新机约 ¥3500；
- 二手 M1 mini（8GB）约 ¥2000，跑 Xcode 16 完全够；
- 显示器用现有的（HDMI），键鼠用 Windows 那套（KVM 切换器约 ¥100）。

注意：Xcode 版本要跟 iOS SDK 匹配，老机器别装最新 Xcode（内存不足会卡）。

---

## 5. 签名与 TestFlight（全程不用 Mac）

这是「没有 Mac 也能上线」的核心链路。iOS 的签名本质是「用 Apple 签发的证书给 App 盖戳」，证书由 Apple 的服务器签发，**不需要 Mac 参与**，只需要：

1. Apple Developer Program 会员（$99/年，个人或公司）；
2. 一个 **App Store Connect API Key**（`.p8` 文件 + Key ID + Issuer ID）；
3. `xcodebuild archive` 时带上 API Key，让它自动申请证书和描述文件。

### 5.1 一次性的账号准备

| 步骤 | 在哪做 | 产出 |
|---|---|---|
| 注册开发者 | developer.apple.com/programs | 团队 ID（10 位，如 `A1B2C3D4E5`） |
| 建 App ID | Certificates, Identifiers & Profiles → Identifiers | `com.yourname.beanman` |
| 建 App 记录 | App Store Connect → My Apps → + | App 的容器（名称、语言、SKU、Bundle ID） |
| 建 API Key | App Store Connect → Users and Access → Integrations → App Store Connect API | `.p8`（只能下一次）、Key ID、Issuer ID |

> 个人开发者账号 $99/年，审核通常 1–3 天；公司账号需要 D-U-N-S 编号，慢一些。

### 5.2 把密钥放进 GitHub Secrets

仓库 → Settings → Secrets and variables → Actions：

| Secret | 内容 |
|---|---|
| `ASC_KEY_ID` | 形如 `2X9ABCD3EF` |
| `ASC_ISSUER_ID` | 形如 `69a6de7c-...`（UUID） |
| `ASC_KEY_P8` | `.p8` 文件的**全文**（含 `-----BEGIN PRIVATE KEY-----`） |
| `APPLE_TEAM_ID` | 10 位团队 ID |

`.p8` 只出现一次，务必当场保存；泄露立刻在 App Store Connect 撤销。

### 5.3 自动签名（不需要下载证书）

```bash
xcodebuild archive \
  -project BeanMan.xcodeproj \
  -scheme BeanMan \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath build/BeanMan.xcarchive \
  -allowProvisioningUpdates \
  -authenticationKeyPath "$RUNNER_TEMP/AuthKey.p8" \
  -authenticationKeyID "$ASC_KEY_ID" \
  -authenticationKeyIssuerID "$ASC_ISSUER_ID" \
  CURRENT_PROJECT_VERSION="$BUILD_NUMBER"
```

`-allowProvisioningUpdates` 的意思是「缺证书/描述文件就自己找 Apple 要」。第一次跑会在团队下自动创建一张 Apple Distribution 证书和 App Store 描述文件。

> 前提：Xcode 工程里 `CODE_SIGN_STYLE = Automatic`，且 `DEVELOPMENT_TEAM` 有值（CI 里用 `DEVELOPMENT_TEAM=$APPLE_TEAM_ID` 覆盖）。

### 5.4 导出 IPA

`ExportOptions.plist`：

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>method</key>            <string>app-store-connect</string>
  <key>teamID</key>            <string>你的TEAMID</string>
  <key>signingStyle</key>      <string>automatic</string>
  <key>uploadSymbols</key>     <true/>
  <key>destination</key>       <string>export</string>
</dict>
</plist>
```

```bash
xcodebuild -exportArchive \
  -archivePath build/BeanMan.xcarchive \
  -exportPath build/export \
  -exportOptionsPlist ExportOptions.plist \
  -allowProvisioningUpdates \
  -authenticationKeyPath "$RUNNER_TEMP/AuthKey.p8" \
  -authenticationKeyID "$ASC_KEY_ID" \
  -authenticationKeyIssuerID "$ASC_ISSUER_ID"
```

> Xcode 15.3 起 `method` 的 `app-store` 改名为 `app-store-connect`；旧值仍兼容但会有警告。

### 5.5 上传到 TestFlight

```bash
xcrun altool --upload-app \
  -f build/export/BeanMan.ipa \
  -t ios \
  --apiKey "$ASC_KEY_ID" \
  --apiIssuer "$ASC_ISSUER_ID" \
  --verbose
```

`altool` 已被标记为废弃（推荐 Transporter 或 `iTMSTransporter`），但目前仍可用。更稳的替代是 fastlane 的 `pilot`：

```ruby
# fastlane/Fastfile
lane :beta do
  build_app(scheme: "BeanMan", export_method: "app-store-connect")
  upload_to_testflight(api_key_path: "fastlane/api_key.json", skip_waiting_for_build_processing: true)
end
```

上传后 5–15 分钟处理完，App Store Connect → TestFlight 里会出现构建，**内测员（最多 100 人）不需要审核**，直接用 TestFlight App 装到 iPhone 上。

> 这一步是「没有 Mac 也能在真机上看效果」的关键：**TestFlight 就是你的真机调试渠道**。

### 5.6 常见报错

| 报错 | 原因 | 解法 |
|---|---|---|
| `No profiles for 'com.yourname.beanman' were found` | 描述文件没生成 | 确认 `-allowProvisioningUpdates` 和 API Key 三个参数都在；App ID 已创建 |
| `Provisioning profile doesn't include signing certificate` | 团队里有旧证书 | 在开发者后台删掉冲突证书，或改用 fastlane match |
| `Invalid Bundle. The bundle at ... does not support the minimum OS Version` | 部署目标比 SDK 高 | 检查 `IPHONEOS_DEPLOYMENT_TARGET` |
| `Missing required icon file` | 没有 AppIcon | 补 `Assets.xcassets/AppIcon.appiconset`（1024×1024 无透明） |
| `ERROR ITMS-90725: SDK Version Issue` | Xcode 太旧 | 用 `macos-15`（Xcode 16） |
| `altool: The provided API key is invalid` | Key ID / Issuer 搞混 | Issuer 是 UUID，Key ID 是 10 位；`.p8` 不要带多余换行 |

---

## 6. 上线清单

### 6.1 提交前（代码与素材）

- [ ] 真机跑通：引导 → 学习 → 完成 → 重启数据还在（TestFlight 装）
- [ ] 深色模式逐页走查
- [ ] 大字号（AX3）不破版
- [ ] VoiceOver 能读完一张卡
- [ ] App 图标 1024×1024，无透明通道，无圆角（系统自己切）
- [ ] 启动屏不是白屏（`UILaunchScreen` 已有）
- [ ] `CFBundleDisplayName` = 豆卡单词
- [ ] 版本号 `CFBundleShortVersionString`（1.0.0）与 `CFBundleVersion`（递增整数）
- [ ] `ITSAppUsesNonExemptEncryption = false`（无网络加密，省掉每次上传的合规问答）
- [ ] 没有 `print` 敏感信息、没有调试入口暴露给用户（`DesignGalleryView` 用 `#if DEBUG` 包住）
- [ ] 崩溃：空词库、空队列、超长例句、10 万词导入

### 6.2 App Store Connect 配置

| 项 | 建议值 |
|---|---|
| 名称 | 豆卡单词（30 字符内，先查重） |
| 副标题 | 打开就能背的离线单词卡 |
| 类别 | 教育（主）/ 效率（次） |
| 年龄分级 | 4+ |
| 价格 | 免费（暂无内购） |
| 隐私政策 URL | 必填；可放 GitHub Pages 一页静态说明 |
| App 隐私 | **不收集数据**（无账号、无网络、无 SDK） |
| 出口合规 | 不使用加密（`ITSAppUsesNonExemptEncryption=false`） |
| 审核备注 | 说明「内置 24 个示例词，用户可自行导入 CSV；无账号、无服务器」 |

### 6.3 截图与文案

必需尺寸（iPhone-only）：

| 尺寸 | 分辨率 | 数量 |
|---|---|---|
| 6.9 英寸 | 1320 × 2868 | 3–10 张（必需） |
| 6.5 英寸 | 1284 × 2778 | 可选（不传则系统缩放） |

截图内容建议（每张一句卖点）：

1. 今日页 —— 「每天只问你要 20 个词」
2. 学习卡背面 —— 「翻面才看答案，记得更牢」
3. 完成页 —— 「10 分钟，收工」
4. 统计页 —— 「进步看得见」
5. 导入页 —— 「自己的词库，一行 CSV」

> 这些截图可以在 CI 的模拟器里截（见 §2.3），也可以在云 Mac 上截；注意状态栏时间统一改成 9:41（模拟器 `simctl status_bar override`）。

### 6.4 审核会挑什么

| 风险 | 说明 | 对策 |
|---|---|---|
| 4.2 Minimum Functionality | 太简单会被拒 | 我们有导入、算法、统计、测试，说明里写清楚 |
| 5.1.1 隐私 | 声明与实际不符 | 我们真的不联网，选「不收集」最安全 |
| 2.1 完整性 | 崩溃/空屏 | 提审前用 TestFlight 跑一遍全部路径 |
| 词库版权 | 内置词被投诉 | 只用自写示例词；关于页写明用户导入内容自负 |
| 4.3 重复应用 | 背单词 App 很多 | 差异化在「离线 + 无账号 + 自建词库」，截图与描述要突出 |
| 名称侵权 | 「豆卡」可能被注册 | 上架前查 App Store 重名 + 中国商标网 |

---

## 7. 时间与成本估算（第一次上线）

| 阶段 | 需要什么 | 耗时 | 花费 |
|---|---|---|---|
| 编译打通 | GitHub 公开仓库 + Actions | 0.5 天 | ¥0 |
| 修编译错误 | 云 Mac 4 小时（可选） | 0.5 天 | ¥20–60 |
| 开发者账号 | 身份证 + 信用卡 | 1–3 天（等审核） | ¥688（$99） |
| 签名 + TestFlight | API Key + 本仓库的 release 工作流 | 0.5 天 | ¥0 |
| 截图与文案 | CI 截图或云 Mac | 1 天 | ¥0–60 |
| 提审到上线 | App Store Connect | 1–3 天（等审核） | ¥0 |
| **合计** | | **约 1 周**（含等待） | **约 ¥700–800** |

---

## 8. 这个仓库现在就能做的三件事

1. **镜像到 GitHub 并开 Actions**（公开仓库，免费）——立刻知道代码能不能编译；
2. **看模拟器截图 artifact** —— 不用 Mac 也能确认今日页长什么样；
3. **拿到开发者账号后配 4 个 Secret** —— `.github/workflows/release-testflight.yml` 一键出 IPA 并传 TestFlight。

> 在此之前，所有 Swift 代码都还没有被编译器验证过（本机是 Windows）。第一步先让 CI 把编译错误吐出来，比继续写新功能更重要。

---

## 9. 可见性策略：测试期 public，完成后自动转 private

| 阶段 | 可见性 | 原因 |
|---|---|---|
| 开发 + 测试期 | **public** | standard macOS runner 免费、不限分钟（私有仓库 2000 分钟 ÷ 10× = 只有 200 分钟 macOS/月） |
| 版本测完 / 准备发布 | **private** | 代码与设计不再公开 |

切换有两个入口，都不需要开浏览器：

**① 打 tag 自动转私有**（推荐，＝「这一版测完了」的语义）

```bash
git tag v0.1.0 && git push github v0.1.0
```

`.github/workflows/repo-visibility.yml` 会调用 GitHub API 把仓库设为 private。

**② 手动切**

```bash
# Actions → 仓库可见性 → Run workflow（选 public / private）
# 或者本地一条命令：
powershell -ExecutionPolicy Bypass -File .\Scripts\repo_visibility.ps1 -Target private
```

依赖：仓库 Secret `ADMIN_TOKEN`（经典 PAT，需 `repo` 权限，且有该仓库 admin 权限）。
新建机器时用 `python Scripts/set_repo_secret.py --repo Shiacc/bean-man --token-file <pat 文件>` 写入（需要 `pip install pynacl`）。

> 转私有后 macOS runner 按 10× 计费：一次 CI（编译 + 单测 + 截图）14–16 分钟 ≈ 150 分钟配额，一个月大约能跑 13 次。日常只 push dev、不跑截图，约 8–12 分钟/次。

---

## 附录：相关文件

| 文件 | 作用 |
|---|---|
| `.github/workflows/ios-build.yml` | 编译 + 单测 + 模拟器截图 |
| `.github/workflows/release-testflight.yml` | Archive → IPA → TestFlight（手动触发，需 Secrets） |
| `project.yml` | XcodeGen 工程描述，CI 每次重新生成 |
| `Scripts/sync.sh` / `sync.ps1` | 双端同步（Gitee / GitHub） |
| `ExportOptions.plist` | 导出配置（release 工作流里内联生成） |