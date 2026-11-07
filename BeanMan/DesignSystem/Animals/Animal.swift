import SwiftUI
import UIKit

/// 小动物名录。
///
/// 一只动物 = 一个场景角色，对应 `Design/Animals/00-小动物总谱.md`。
/// 资源命名约定：`Juzi` / `JuziHappy` / `JuziBlink`（imageset 同名）。
/// 素材还没画出来的动物也不会崩：会退化成主色 + 爪印占位。
enum Animal: String, CaseIterable, Identifiable, Hashable {
    case juzi      // 橘猫 · 学习陪伴
    case dango     // 柴犬 · 连续打卡
    case mianhua   // 垂耳兔 · 新词
    case zhima     // 仓鼠 · 生词本
    case zhuzhu    // 熊猫 · 复习
    case douya     // 小鸡 · 首次引导
    case manman    // 树懒 · 提醒
    case paopao    // 水獭 · 测试
    case shanshan  // 萤火虫 · 特效 / 夜间
    case buding    // 柯基 · 完成庆祝
    case guagua    // 青蛙 · 补签
    case cici      // 刺猬 · 错词本
    case xueqiu    // 白兔 · 空状态
    case awu       // 小恐龙 · 成就
    case jiujiu    // 麻雀 · 通知
    case juanjuan  // 小羊 · 专注
    case kaka      // 螃蟹 · 错题
    case yunduo    // 海豹 · 加载
    case gulu      // 小熊 · 词库
    case youzi     // 狐狸 · 设置

    var id: String { rawValue }

    /// 中文名，给用户看
    var displayName: String {
        switch self {
        case .juzi: "橘子"
        case .dango: "团子"
        case .mianhua: "棉花"
        case .zhima: "芝麻"
        case .zhuzhu: "竹竹"
        case .douya: "豆芽"
        case .manman: "慢慢"
        case .paopao: "泡泡"
        case .shanshan: "闪闪"
        case .buding: "布丁"
        case .guagua: "呱呱"
        case .cici: "刺刺"
        case .xueqiu: "雪球"
        case .awu: "啊呜"
        case .jiujiu: "啾啾"
        case .juanjuan: "卷卷"
        case .kaka: "咔咔"
        case .yunduo: "云朵"
        case .gulu: "咕噜"
        case .youzi: "小柚"
        }
    }

    /// 资源前缀，等于 imageset 名：Juzi / Dango …
    var assetName: String {
        rawValue.prefix(1).uppercased() + rawValue.dropFirst()
    }

    /// 它在这个 App 里负责什么
    var role: String {
        switch self {
        case .juzi: "学习陪伴"
        case .dango: "连续打卡"
        case .mianhua: "新词出现"
        case .zhima: "生词本"
        case .zhuzhu: "到期复习"
        case .douya: "首次引导"
        case .manman: "提醒设置"
        case .paopao: "测试"
        case .shanshan: "夜间与特效"
        case .buding: "完成庆祝"
        case .guagua: "补签日历"
        case .cici: "错词本"
        case .xueqiu: "空状态"
        case .awu: "成就解锁"
        case .jiujiu: "通知"
        case .juanjuan: "专注计时"
        case .kaka: "错题回顾"
        case .yunduo: "启动加载"
        case .gulu: "词库"
        case .youzi: "设置"
        }
    }

    /// 主色：素材缺位时用它上色，也用于胶囊底色
    var accent: Color {
        switch self {
        case .juzi: Color(hex: 0xE4703A)
        case .dango: Color(hex: 0xD89B4A)
        case .mianhua: Color(hex: 0xF2D7C2)
        case .zhima: Color(hex: 0xC9A227)
        case .zhuzhu: Color(hex: 0x3A2A22)
        case .douya: Color(hex: 0xF5C542)
        case .manman: Color(hex: 0x8C7A66)
        case .paopao: Color(hex: 0x6FA8A0)
        case .shanshan: Color(hex: 0xF2C14E)
        case .buding: Color(hex: 0xE39B5C)
        case .guagua: Color(hex: 0x7FB069)
        case .cici: Color(hex: 0xA9744F)
        case .xueqiu: Color(hex: 0xEDE7DD)
        case .awu: Color(hex: 0x6BA292)
        case .jiujiu: Color(hex: 0x9BB4C9)
        case .juanjuan: Color(hex: 0xE8E2D5)
        case .kaka: Color(hex: 0xE2725B)
        case .yunduo: Color(hex: 0xBFD3E0)
        case .gulu: Color(hex: 0xB08050)
        case .youzi: Color(hex: 0xD97742)
        }
    }

    /// 这套表情资源是否已经画好并进包
    func isAvailable(_ expression: AnimalExpression = .normal) -> Bool {
        UIImage(named: assetName(for: expression)) != nil
    }

    /// 表情对应的资源名：常态是 `Juzi`，其余是 `JuziHappy`
    func assetName(for expression: AnimalExpression) -> String {
        expression == .normal ? assetName : assetName + expression.suffix
    }
}

/// 一只动物需要的表情档位
enum AnimalExpression: String, CaseIterable, Hashable {
    case normal
    case happy
    case blink
    case sleepy
    case surprised

    /// 资源名后缀（常态无后缀）
    var suffix: String {
        switch self {
        case .normal: ""
        case .happy: "Happy"
        case .blink: "Blink"
        case .sleepy: "Sleepy"
        case .surprised: "Surprised"
        }
    }
}