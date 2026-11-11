import SwiftUI
import UIKit

/// 设计 token —— 与 Figma 文件 `app-design / beanman-ios` 里的变量集合 `BeanMan / Color` 一一对应。
/// 改色只改这里；SwiftUI 侧不允许出现裸 `Color(red:...)`。
///
/// 每个 token 都是「亮 / 暗」成对：跟随系统外观自动切换（PRD §8.5）。
/// 暗色值都过了对比度自检（`BeanManTests/ThemeContrastTests.swift`）。
enum Theme {

    // MARK: - 颜色（变量名 → 十六进制 → Swift 常量）

    enum Palette {
        // 每个 token 都写成「UI 原值 + Color」两行：`*UI` 给测试解析亮/暗配色算对比度用，
        // 界面里一律用下面的 `Color`。改色只改这一块。
        static let brandUI        = UIColor.dynamic(light: 0xE4703A, dark: 0xF0854F)   // brand
        static let brandPressedUI = UIColor.dynamic(light: 0xB04E1A, dark: 0xE0703F)   // brand/pressed（亮色压深一点，色块上的小字才够 4.5:1）
        static let brandTintUI    = UIColor.dynamic(light: 0xFFF1E8, dark: 0x2E1F17)   // brand/tint
        static let brandSoftUI    = UIColor.dynamic(light: 0xF8D9C6, dark: 0x4A2E20)   // brand/soft

        static let bgUI           = UIColor.dynamic(light: 0xFFFFFF, dark: 0x151311)   // bg
        static let surfaceUI      = UIColor.dynamic(light: 0xF7F5F1, dark: 0x1E1B18)   // surface
        static let surfaceAltUI   = UIColor.dynamic(light: 0xEDE9E2, dark: 0x2A2622)   // surface/alt
        static let borderUI       = UIColor.dynamic(light: 0xE6E1D8, dark: 0x3A352E)   // border

        static let textPrimaryUI   = UIColor.dynamic(light: 0x1C1B18, dark: 0xF3EFE8)  // text/primary
        static let textSecondaryUI = UIColor.dynamic(light: 0x6E6962, dark: 0xB6AFA4)  // text/secondary
        static let textTertiaryUI  = UIColor.dynamic(light: 0xA39D93, dark: 0x938B7F)  // text/tertiary

        static let successUI      = UIColor.dynamic(light: 0x2F8F4E, dark: 0x5FBF7E)
        static let successTintUI  = UIColor.dynamic(light: 0xE8F4EC, dark: 0x1B2E22)
        static let warningUI      = UIColor.dynamic(light: 0xC98A12, dark: 0xE0A93B)
        static let warningTintUI  = UIColor.dynamic(light: 0xFBF0D9, dark: 0x332A16)
        static let dangerUI       = UIColor.dynamic(light: 0xD93A2B, dark: 0xF06B5C)
        static let dangerTintUI   = UIColor.dynamic(light: 0xFBE9E7, dark: 0x3A1F1B)
        static let overlayUI      = UIColor.dynamic(light: 0x1C1B18, dark: 0x000000)

        /// 品牌色块上的字/图标。亮色用白，暗色用近黑——橙底配白字对比度只有 3:1，
        /// 暗色模式顺手改成深色字，反而更清楚。
        static let onBrandUI      = UIColor.dynamic(light: 0xFFFFFF, dark: 0x1C1B18)

        static let brand        = Color(uiColor: brandUI)
        static let brandPressed = Color(uiColor: brandPressedUI)
        static let brandTint    = Color(uiColor: brandTintUI)
        static let brandSoft    = Color(uiColor: brandSoftUI)

        static let bg           = Color(uiColor: bgUI)
        static let surface      = Color(uiColor: surfaceUI)
        static let surfaceAlt   = Color(uiColor: surfaceAltUI)
        static let border       = Color(uiColor: borderUI)

        static let textPrimary   = Color(uiColor: textPrimaryUI)
        static let textSecondary = Color(uiColor: textSecondaryUI)
        static let textTertiary  = Color(uiColor: textTertiaryUI)

        static let success      = Color(uiColor: successUI)
        static let successTint  = Color(uiColor: successTintUI)
        static let warning      = Color(uiColor: warningUI)
        static let warningTint  = Color(uiColor: warningTintUI)
        static let danger       = Color(uiColor: dangerUI)
        static let dangerTint   = Color(uiColor: dangerTintUI)
        static let overlay      = Color(uiColor: overlayUI)

        static let onBrand      = Color(uiColor: onBrandUI)
    }

    // MARK: - 圆角

    enum Radius {
        static let card: CGFloat = 22
        static let studyCard: CGFloat = 24
        static let button: CGFloat = 16
        static let chip: CGFloat = 13
        static let rating: CGFloat = 14
        static let tile: CGFloat = 16
    }

    // MARK: - 间距

    enum Spacing {
        static let screenH: CGFloat = 20     // 屏幕左右边距
        static let cardPadding: CGFloat = 24
        static let sectionGap: CGFloat = 16
    }

    // MARK: - 字号（配合 Dynamic Type 使用 .font(.system(size:)) + .dynamicTypeSize 上限）

    enum Font {
        static let screenTitle = SwiftUI.Font.system(size: 26, weight: .bold)
        static let date        = SwiftUI.Font.system(size: 13)
        static let cardTitle   = SwiftUI.Font.system(size: 22, weight: .bold)
        static let bigNumber   = SwiftUI.Font.system(size: 34, weight: .bold)
        static let statNumber  = SwiftUI.Font.system(size: 24, weight: .bold)
        static let body        = SwiftUI.Font.system(size: 14)
        static let bodySmall   = SwiftUI.Font.system(size: 12)
        static let caption     = SwiftUI.Font.system(size: 11)
        static let wordLarge   = SwiftUI.Font.system(size: 34, weight: .bold)
        static let wordMedium  = SwiftUI.Font.system(size: 22, weight: .bold)
        static let meaning     = SwiftUI.Font.system(size: 26, weight: .bold)
        static let button      = SwiftUI.Font.system(size: 16, weight: .medium)
    }

    // MARK: - 阴影（卡片浮起）

    /// 卡片投影：暗色下几乎没有「阴影」可言，加一点深度更稳。
    static let cardShadow = Color(uiColor: UIColor { traits in
        UIColor(white: 0, alpha: traits.userInterfaceStyle == .dark ? 0.45 : 0.08)
    })
    static let cardShadowRadius: CGFloat = 18
    static let cardShadowY: CGFloat = 6
}

// MARK: - 十六进制颜色

extension Color {
    /// `Color(hex: 0xE4703A)` —— 单值颜色（动物配色、弹幕主题这类固定色用）。
    init(hex: UInt32, alpha: Double = 1) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: alpha)
    }
}

extension UIColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        self.init(red: CGFloat((hex >> 16) & 0xFF) / 255,
                  green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255,
                  alpha: alpha)
    }

    /// 亮 / 暗双值颜色：跟随系统外观自动切换（`Theme.Palette` 的唯一颜色来源）。
    static func dynamic(light: UInt32, dark: UInt32) -> UIColor {
        UIColor { traits in
            UIColor(hex: traits.userInterfaceStyle == .dark ? dark : light)
        }
    }
}

// MARK: - 卡片的统一外观

struct CardStyle: ViewModifier {
    var radius: CGFloat = Theme.Radius.card
    var fill: Color = Theme.Palette.bg
    var stroke: Color? = Theme.Palette.border
    var shadowed: Bool = true

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(fill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(stroke ?? .clear, lineWidth: stroke == nil ? 0 : 1)
            )
            .shadow(color: shadowed ? Theme.cardShadow : .clear,
                    radius: shadowed ? Theme.cardShadowRadius : 0,
                    y: shadowed ? Theme.cardShadowY : 0)
    }
}

extension View {
    func cardStyle(radius: CGFloat = Theme.Radius.card,
                   fill: Color = Theme.Palette.bg,
                   stroke: Color? = Theme.Palette.border,
                   shadowed: Bool = true) -> some View {
        modifier(CardStyle(radius: radius, fill: fill, stroke: stroke, shadowed: shadowed))
    }
}