import SwiftUI

/// 场景插画：由 AI 生成、保留米色底的整幅画面（不是透明贴纸）。
///
/// 与 `Animal`（透明贴纸角色）分工：
/// - `AnimalView` —— 页面里的小角色，可换表情、可飘浮；
/// - `SceneArtView` —— 空状态、引导、庆祝这类需要「一整幅画面」的位置。
///
/// 缺图时回落到品牌色为主的占位，不会裂开。
enum SceneArt: String, CaseIterable, Identifiable {
    case onboardingWelcome
    case onboardingPlan
    case onboardingReminder
    case onboardingDone
    case emptyToday
    case emptyWrongBook
    case emptyFavorites
    case emptyDeck
    case emptyQuiz
    case achievement
    case streak
    case insight
    case comeback
    case study
    case review
    case night

    var id: String { rawValue }

    /// 资源名 = `Scene` + 首字母大写
    var assetName: String {
        "Scene" + rawValue.prefix(1).uppercased() + rawValue.dropFirst()
    }

    /// 有没有真的把图放进 Assets（设计验收页用）
    var isAvailable: Bool {
        UIImage(named: assetName) != nil
    }

    var accessibilityLabel: String {
        switch self {
        case .onboardingWelcome: "一只橘猫坐在书桌前看单词卡"
        case .onboardingPlan: "一只刚破壳的小鸡举着小旗"
        case .onboardingReminder: "一只树懒抱着闹钟挂在树枝上"
        case .onboardingDone: "一只柯基戴着派对帽撒彩带"
        case .emptyToday: "一只垂耳兔在给刚发芽的小苗浇水"
        case .emptyWrongBook: "一只刺猬旁边散落着几张卡片"
        case .emptyFavorites: "一只仓鼠把卡片塞进腮帮子"
        case .emptyDeck: "一只小熊站在书架旁拿着一本书"
        case .emptyQuiz: "一只水獭举着几张题卡"
        case .achievement: "一只小恐龙戴着奖牌"
        case .streak: "一只白兔站在打了勾的日历旁"
        case .insight: "一只熊猫拿着放大镜看三张卡片"
        case .comeback: "一只青蛙打着伞站在小雨里"
        case .study: "一只柴犬趴着看书"
        case .review: "一只熊猫坐在竹子里拿着清单"
        case .night: "一只萤火虫在夜里发光"
        }
    }
}

/// 场景插画视图：等比填满、圆角裁切。
@MainActor
struct SceneArtView: View {
    let scene: SceneArt
    var cornerRadius: CGFloat = Theme.Radius.card
    var height: CGFloat? = nil

    var body: some View {
        Group {
            if let image = UIImage(named: scene.assetName) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .accessibilityLabel(scene.accessibilityLabel)
            } else {
                placeholder
            }
        }
        // 插画是 1:1 的：按宽度定高，避免被容器裁掉上下
        .aspectRatio(1, contentMode: .fit)
        .frame(maxWidth: .infinity)
        .frame(maxHeight: height)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(Theme.Palette.border, lineWidth: 1)
        }
    }

    private var placeholder: some View {
        ZStack {
            Theme.Palette.brandTint
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 34))
                .foregroundStyle(Theme.Palette.brand.opacity(0.5))
        }
    }
}

#Preview("场景插画") {
    ScrollView {
        VStack(spacing: 16) {
            ForEach(SceneArt.allCases) { scene in
                VStack(alignment: .leading, spacing: 6) {
                    SceneArtView(scene: scene, height: 180)
                    Text(scene.assetName)
                        .font(Theme.Font.caption)
                        .foregroundStyle(Theme.Palette.textTertiary)
                }
            }
        }
        .padding(Theme.Spacing.screenH)
    }
    .background(Theme.Palette.bg)
}