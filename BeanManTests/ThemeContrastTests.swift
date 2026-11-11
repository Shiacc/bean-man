import XCTest
import UIKit
@testable import BeanMan

/// 深色模式自检（PRD §8.5 / 验收 AC-83）：
///
/// 1. 每个 token 都真的有亮/暗两套值——只改亮色的 token 会在暗色下「白底白字」；
/// 2. 暗色下背景变暗、文字变亮；
/// 3. 正文 / 次要文字 / 品牌色在两种外观下的对比度达标。
///
/// 对比度按 WCAG 2.1：正文 ≥ 7:1（AAA）、次要文字 ≥ 4.5:1（AA）、图标/大字号 ≥ 3:1。
final class ThemeContrastTests: XCTestCase {

    private struct RGBA: Equatable {
        let red: Double
        let green: Double
        let blue: Double
    }

    private func rgba(_ color: UIColor, dark: Bool) -> RGBA {
        let style: UIUserInterfaceStyle = dark ? .dark : .light
        let resolved = color.resolvedColor(with: UITraitCollection(userInterfaceStyle: style))
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        resolved.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return RGBA(red: Double(red), green: Double(green), blue: Double(blue))
    }

    private func luminance(_ color: UIColor, dark: Bool) -> Double {
        let value = rgba(color, dark: dark)
        func channel(_ component: Double) -> Double {
            component <= 0.03928 ? component / 12.92 : pow((component + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * channel(value.red)
            + 0.7152 * channel(value.green)
            + 0.0722 * channel(value.blue)
    }

    private func contrast(_ foreground: UIColor, _ background: UIColor, dark: Bool) -> Double {
        let a = luminance(foreground, dark: dark)
        let b = luminance(background, dark: dark)
        return (max(a, b) + 0.05) / (min(a, b) + 0.05)
    }

    /// 全部 19 个 token。加新 token 时记得一起加进来。
    private var tokens: [(String, UIColor)] {
        [
            ("brand", Theme.Palette.brandUI),
            ("brandPressed", Theme.Palette.brandPressedUI),
            ("brandTint", Theme.Palette.brandTintUI),
            ("brandSoft", Theme.Palette.brandSoftUI),
            ("bg", Theme.Palette.bgUI),
            ("surface", Theme.Palette.surfaceUI),
            ("surfaceAlt", Theme.Palette.surfaceAltUI),
            ("border", Theme.Palette.borderUI),
            ("textPrimary", Theme.Palette.textPrimaryUI),
            ("textSecondary", Theme.Palette.textSecondaryUI),
            ("textTertiary", Theme.Palette.textTertiaryUI),
            ("success", Theme.Palette.successUI),
            ("successTint", Theme.Palette.successTintUI),
            ("warning", Theme.Palette.warningUI),
            ("warningTint", Theme.Palette.warningTintUI),
            ("danger", Theme.Palette.dangerUI),
            ("dangerTint", Theme.Palette.dangerTintUI),
            ("overlay", Theme.Palette.overlayUI),
            ("onBrand", Theme.Palette.onBrandUI)
        ]
    }

    func testEveryTokenHasBothAppearances() {
        for (name, color) in tokens {
            XCTAssertNotEqual(rgba(color, dark: false), rgba(color, dark: true),
                              "\(name) 的亮色和暗色是同一个值：暗色模式下会糊掉")
        }
    }

    func testBackgroundGetsDarkerAndTextGetsLighter() {
        XCTAssertGreaterThan(luminance(Theme.Palette.bgUI, dark: false), 0.85, "亮色底应该是白的")
        XCTAssertLessThan(luminance(Theme.Palette.bgUI, dark: true), 0.05, "暗色底应该接近黑")
        XCTAssertLessThan(luminance(Theme.Palette.textPrimaryUI, dark: false), 0.05, "亮色正文应该接近黑")
        XCTAssertGreaterThan(luminance(Theme.Palette.textPrimaryUI, dark: true), 0.7, "暗色正文应该接近白")
    }

    func testBodyTextContrastInBothModes() {
        for dark in [false, true] {
            let mode = dark ? "暗色" : "亮色"
            XCTAssertGreaterThanOrEqual(
                contrast(Theme.Palette.textPrimaryUI, Theme.Palette.bgUI, dark: dark), 7,
                "\(mode)：正文 / 页面底 对比度不足")
            XCTAssertGreaterThanOrEqual(
                contrast(Theme.Palette.textPrimaryUI, Theme.Palette.surfaceUI, dark: dark), 7,
                "\(mode)：正文 / 卡片底 对比度不足")
            XCTAssertGreaterThanOrEqual(
                contrast(Theme.Palette.textPrimaryUI, Theme.Palette.surfaceAltUI, dark: dark), 7,
                "\(mode)：正文 / 二级底 对比度不足")
            XCTAssertGreaterThanOrEqual(
                contrast(Theme.Palette.textSecondaryUI, Theme.Palette.bgUI, dark: dark), 4.5,
                "\(mode)：次要文字 对比度不足")
            XCTAssertGreaterThanOrEqual(
                contrast(Theme.Palette.textSecondaryUI, Theme.Palette.surfaceUI, dark: dark), 4.5,
                "\(mode)：次要文字 / 卡片底 对比度不足")
        }
    }

    func testBrandContrastInBothModes() {
        for dark in [false, true] {
            let mode = dark ? "暗色" : "亮色"
            // 品牌橙用作图标、大字号数字、「开始学习」这类大按钮的底色，按 3:1 要求。
            XCTAssertGreaterThanOrEqual(
                contrast(Theme.Palette.brandUI, Theme.Palette.bgUI, dark: dark), 3,
                "\(mode)：品牌色 / 页面底 对比度不足")
            // 橙色 chip 上的小字（统计页的小豆一句话、词库的到期 chip）。
            XCTAssertGreaterThanOrEqual(
                contrast(Theme.Palette.brandPressedUI, Theme.Palette.brandTintUI, dark: dark), 4.5,
                "\(mode)：橙色小字 / 橙底 对比度不足")
            // 小豆气泡、盯住卡片上的正文。
            XCTAssertGreaterThanOrEqual(
                contrast(Theme.Palette.textPrimaryUI, Theme.Palette.brandTintUI, dark: dark), 7,
                "\(mode)：正文 / 橙底 对比度不足")
        }
    }
}