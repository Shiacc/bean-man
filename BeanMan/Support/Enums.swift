import Foundation

/// 四档反馈。rawValue 直接对应简化 SM-2 的评分（Again=1 / Hard=3 / Good=4 / Easy=5）。
enum Rating: Int, CaseIterable, Identifiable {
    case again = 1
    case hard = 3
    case good = 4
    case easy = 5

    var id: Int { rawValue }

    /// 界面上显示的名字（与 Figma 组件 DS/Rating/* 一致）。
    var title: String {
        switch self {
        case .again: return "不认识"
        case .hard:  return "模糊"
        case .good:  return "认识"
        case .easy:  return "很简单"
        }
    }

    /// 是否算作「答对」，用于正确率统计。
    var isCorrect: Bool { self == .good || self == .easy }

    /// 是否需要进错词本。
    var needsReviewList: Bool { self == .again || self == .hard }
}

/// 记忆阶段。MVP 只区分「新词」与「复习中」；Relearning 留给 FSRS 升级时用。
enum StudyPhase: String, Codable {
    case new
    case learning
    case review
    case relearning
}

/// 发音口音。
enum VoiceAccent: String, Codable, CaseIterable, Identifiable {
    case american
    case british

    var id: String { rawValue }

    var title: String {
        switch self {
        case .american: return "美音"
        case .british:  return "英音"
        }
    }

    /// AVSpeechSynthesisVoice 的语言标识。
    var languageCode: String {
        switch self {
        case .american: return "en-US"
        case .british:  return "en-GB"
        }
    }
}