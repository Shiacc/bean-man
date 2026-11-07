import SwiftUI

/// 设计 token —— 与 Figma 文件 `app-design / beanman-ios` 里的变量集合 `BeanMan / Color` 一一对应。
/// 改色只改这里；SwiftUI 侧不允许出现裸 `Color(red:...)`。
enum Theme {

    // MARK: - 颜色（变量名 → 十六进制 → Swift 常量）

    enum Palette {
        static let brand        = Color(hex: 0xE4703A)   // brand
        static let brandPressed = Color(hex: 0xC2571F)   // brand/pressed
        static let brandTint    = Color(hex: 0xFFF1E8)   // brand/tint
        static let brandSoft    = Color(hex: 0xF8D9C6)   // brand/soft

        static let bg           = Color(hex: 0xFFFFFF)   // bg
        static let surface      = Color(hex: 0xF7F5F1)   // surface
        static let surfaceAlt   = Color(hex: 0xEDE9E2)   // surface/alt
        static let border       = Color(hex: 0xE6E1D8)   // border

        static let textPrimary   = Color(hex: 0x1C1B18)  // text/primary
        static let textSecondary = Color(hex: 0x6E6962)  // text/secondary
        static let textTertiary  = Color(hex: 0xA39D93)  // text/tertiary

        static let success      = Color(hex: 0x2F8F4E)
        static let successTint  = Color(hex: 0xE8F4EC)
        static let warning      = Color(hex: 0xC98A12)
        static let warningTint  = Color(hex: 0xFBF0D9)
        static let danger       = Color(hex: 0xD93A2B)
        static let dangerTint   = Color(hex: 0xFBE9E7)
        static let overlay      = Color(hex: 0x1C1B18)
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

    static let cardShadow = Color.black.opacity(0.08)
    static let cardShadowRadius: CGFloat = 18
    static let cardShadowY: CGFloat = 6
}

// MARK: - 十六进制颜色

extension Color {
    /// `Color(hex: 0xE4703A)`
    init(hex: UInt32, alpha: Double = 1) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: alpha)
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