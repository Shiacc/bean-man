import Foundation
import Observation
import SwiftData

/// 错词本页的状态。
///
/// 只做三件事：取快照、按筛选/搜索切列表、把「移出 / 恢复 / 发起复习」转给 Service。
@MainActor
@Observable
final class WrongBookViewModel {

    enum Filter: String, CaseIterable, Identifiable {
        case due
        case all
        case hidden

        var id: String { rawValue }

        var title: String {
            switch self {
            case .due:    return "待复习"
            case .all:    return "全部"
            case .hidden: return "已移出"
            }
        }
    }

    var filter: Filter = .due
    var searchText: String = ""

    private(set) var snapshot = WrongBookSnapshot()
    private(set) var errorMessage: String?

    // MARK: - 数字

    var visibleCount: Int { snapshot.visibleCount }
    var dueCount: Int { snapshot.dueCount }
    var hiddenCount: Int { snapshot.hiddenCount }

    var canStartReview: Bool { visibleCount > 0 }

    var reviewButtonTitle: String {
        guard visibleCount > 0 else { return "还没有错词" }
        let n = min(visibleCount, 20)
        return "复习这 \(n) 个错词"
    }

    var xiaodouMoment: XiaodouMoment { .wrongBook(count: visibleCount) }

    // MARK: - 列表

    var entries: [WrongWordEntry] {
        let base: [WrongWordEntry]
        switch filter {
        case .due:    base = snapshot.entries.filter { !$0.isHidden && $0.isDue }
        case .all:    base = snapshot.entries.filter { !$0.isHidden }
        case .hidden: base = snapshot.entries.filter { $0.isHidden }
        }

        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return base }
        return base.filter { entry in
            entry.word.normalized.contains(query)
                || entry.word.meaning.lowercased().contains(query)
        }
    }

    var isEmpty: Bool { entries.isEmpty }

    var emptyTitle: String {
        if !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "没找到这个词"
        }
        switch filter {
        case .due:    return visibleCount > 0 ? "今天没有要复习的错词" : "还没有错词"
        case .all:    return "还没有错词"
        case .hidden: return "没有移出过的词"
        }
    }

    var emptyDetail: String {
        if !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "换个拼法，或者只输前几个字母"
        }
        switch filter {
        case .due:    return visibleCount > 0 ? "可以先翻翻「全部」，挑几个先过一遍" : "学习时标记「不认识」或「模糊」，词会自动进来"
        case .all:    return "学习时标记「不认识」或「模糊」，词会自动进来"
        case .hidden: return "移出过的词会留在这里，随时可以放回去"
        }
    }

    // MARK: - 读取

    func refresh(context: ModelContext) {
        do {
            snapshot = try WrongBookService.snapshot(context: context)
            errorMessage = nil
        } catch {
            snapshot = .empty
            errorMessage = "读取错词本失败：\(error.localizedDescription)"
        }
    }

    func makeQueue(context: ModelContext, limit: Int = 20) -> [QueueItem] {
        do {
            return try WrongBookService.reviewQueue(context: context, limit: limit)
        } catch {
            errorMessage = "生成复习队列失败：\(error.localizedDescription)"
            return []
        }
    }

    // MARK: - 写

    func hide(_ entry: WrongWordEntry, context: ModelContext) {
        do {
            try WrongBookService.hide(entry.word, context: context)
            refresh(context: context)
        } catch {
            errorMessage = "移出失败：\(error.localizedDescription)"
        }
    }

    func restore(_ entry: WrongWordEntry, context: ModelContext) {
        do {
            try WrongBookService.restore(entry.word, context: context)
            refresh(context: context)
        } catch {
            errorMessage = "恢复失败：\(error.localizedDescription)"
        }
    }
}