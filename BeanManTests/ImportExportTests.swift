import XCTest
import SwiftData
@testable import BeanMan

@MainActor
final class CSVParserTests: XCTestCase {

    func testParsesSimpleTable() throws {
        let table = try CSVParser.parse("word,meaning\nabandon,放弃\nbenefit,好处\n")
        XCTAssertEqual(table.header, ["word", "meaning"])
        XCTAssertEqual(table.rows, [["abandon", "放弃"], ["benefit", "好处"]])
    }

    func testHandlesBOMAndCRLF() throws {
        let text = "\u{FEFF}word,meaning\r\ntidy,整洁\r\n"
        let table = try CSVParser.parse(text)
        XCTAssertEqual(table.header, ["word", "meaning"])
        XCTAssertEqual(table.rows, [["tidy", "整洁"]])
    }

    func testQuotedFieldsKeepCommasAndNewlines() throws {
        let text = "word,meaning\n\"give up\",\"放弃, 认输\"\n\"note\",\"第一行\n第二行\"\n"
        let table = try CSVParser.parse(text)
        XCTAssertEqual(table.rows.count, 2)
        XCTAssertEqual(table.rows[0], ["give up", "放弃, 认输"])
        XCTAssertEqual(table.rows[1], ["note", "第一行\n第二行"])
    }

    func testEscapedQuotes() throws {
        let table = try CSVParser.parse("word,meaning\na,\"say \"\"hi\"\"\"\n")
        XCTAssertEqual(table.rows[0][1], "say \"hi\"")
    }

    func testPadsShortRows() throws {
        let table = try CSVParser.parse("word,phonetic,meaning\na,,意思\n")
        XCTAssertEqual(table.rows[0], ["a", "", "意思"])
    }

    func testEmptyFileThrows() {
        XCTAssertThrowsError(try CSVParser.parse("")) { error in
            XCTAssertEqual(error as? CSVError, .emptyFile)
        }
    }

    func testUnclosedQuoteThrows() {
        XCTAssertThrowsError(try CSVParser.parse("word,meaning\n\"abandon,放弃\n")) { error in
            guard case let .unclosedQuote(line)? = error as? CSVError else {
                return XCTFail("应该是 unclosedQuote")
            }
            XCTAssertGreaterThan(line, 0)
        }
    }

    func testBlankLinesAreDropped() throws {
        let table = try CSVParser.parse("word,meaning\n\nabandon,放弃\n\n")
        XCTAssertEqual(table.rows.count, 1)
    }
}

@MainActor
final class DeckImporterTests: XCTestCase {

    private var container: ModelContainer!
    private var context: ModelContext!

    override func setUp() async throws {
        container = BeanManStore.makeContainer(inMemory: true)
        context = ModelContext(container)
        BeanManStore.bootstrap(context)
        // 示例词库里本来就有 abandon / quiet / tidy 这些词，留着会让断言数到两个。
        // 先把内置词库删掉，测试只针对导入结果。
        for deck in try context.fetch(FetchDescriptor<Deck>()) where deck.isBuiltIn {
            context.delete(deck)
        }
        try context.save()
    }

    override func tearDown() async throws {
        context = nil
        container = nil
    }

    func testImportsIntoNewDeck() throws {
        let csv = """
        word,phonetic,partOfSpeech,meaning,example,exampleTranslation,tags,note
        abandon,/əˈbændən/,v.,放弃,They abandoned the car.,他们弃车了。,情绪,常考
        benefit,/ˈbenɪfɪt/,n.,好处,,,,
        """

        let report = try DeckImporter.importCSV(text: csv, deckName: "测试词库", context: context)

        XCTAssertEqual(report.imported, 2)
        XCTAssertEqual(report.deckName, "测试词库")
        let words = try context.fetch(FetchDescriptor<Word>(predicate: #Predicate { $0.word == "abandon" }))
        XCTAssertEqual(words.count, 1)
        XCTAssertEqual(words.first?.phonetic, "/əˈbændən/")
        XCTAssertEqual(words.first?.tags, ["情绪"])
    }

    func testChineseHeaderAliases() throws {
        let csv = "单词,音标,词性,释义\nquiet,/ˈkwaɪət/,adj.,安静的\n"
        let report = try DeckImporter.importCSV(text: csv, deckName: "中文表头", context: context)
        XCTAssertEqual(report.imported, 1)

        let words = try context.fetch(FetchDescriptor<Word>(predicate: #Predicate { $0.word == "quiet" }))
        XCTAssertEqual(words.first?.meaning, "安静的")
    }

    func testSkipsDuplicateWords() throws {
        let csv = "word,meaning\ntidy,整洁\nTidy,整洁\nTIDY,整洁的\n"
        let report = try DeckImporter.importCSV(text: csv, deckName: "重复", context: context)
        XCTAssertEqual(report.imported, 1)
        XCTAssertEqual(report.skippedDuplicate, 2)
    }

    func testRecordsInvalidRows() throws {
        let csv = "word,meaning\n,空单词\ngather,\nvalue,价值\n"
        let report = try DeckImporter.importCSV(text: csv, deckName: "有错", context: context)
        XCTAssertEqual(report.imported, 1)
        XCTAssertEqual(report.skippedInvalid, 2)
        XCTAssertEqual(report.issues.count, 2)
        XCTAssertEqual(report.issues[0].row, 2)
    }

    func testMissingColumnsThrows() {
        let csv = "foo,bar\na,b\n"
        XCTAssertThrowsError(try DeckImporter.importCSV(text: csv, deckName: "缺列", context: context)) { error in
            XCTAssertTrue(error is ImportError)
        }
    }

    func testAppendsToExistingDeck() throws {
        // 自己建一个词库：setUp 里已经把内置示例词库删掉了
        let deck = Deck(name: "已有词库", summary: "", sortIndex: 0)
        context.insert(deck)
        let existing = Word(deckID: deck.id, word: "keep", meaning: "保留")
        context.insert(existing)
        deck.words.append(existing)
        try context.save()

        let before = deck.words.count

        let report = try DeckImporter.importCSV(text: "word,meaning\nzzztest,测试词\n",
                                                deckName: "忽略",
                                                appendingTo: deck,
                                                context: context)

        XCTAssertEqual(report.imported, 1)
        XCTAssertEqual(deck.words.count, before + 1)
        XCTAssertEqual(report.deckID, deck.id)
    }

    func testNewDeckBecomesSelected() throws {
        _ = try DeckImporter.importCSV(text: "word,meaning\nnewone,新词\n", deckName: "新库", context: context)
        let settings = try XCTUnwrap(try AppSettingsStore.current(in: context))
        let decks = try context.fetch(FetchDescriptor<Deck>())
        let selected = decks.first { $0.id == settings.selectedDeckID }
        XCTAssertEqual(selected?.name, "新库")
    }
}

@MainActor
final class BackupServiceTests: XCTestCase {

    private var container: ModelContainer!
    private var context: ModelContext!

    override func setUp() async throws {
        container = BeanManStore.makeContainer(inMemory: true)
        context = ModelContext(container)
        BeanManStore.bootstrap(context)
    }

    override func tearDown() async throws {
        context = nil
        container = nil
    }

    func testRoundTrip() throws {
        // 先给一个词加复习状态，确认会被导出
        let words = try context.fetch(FetchDescriptor<Word>())
        let word = try XCTUnwrap(words.first)
        let state = ReviewState(wordID: word.id,
                                deckID: word.deckID,
                                easeFactor: 2.5,
                                intervalDays: 8,
                                repetitions: 3,
                                dueDate: Date(timeIntervalSince1970: 1_800_000_000),
                                lapses: 1,
                                phase: .review)
        context.insert(state)
        word.reviewState = state
        try context.save()

        let backup = try BackupService.makeBackup(context: context,
                                                  now: Date(timeIntervalSince1970: 1_800_000_000))
        let data = try BackupService.encode(backup)

        let restored = try BackupService.decode(data)
        XCTAssertEqual(restored.schemaVersion, BackupService.currentSchemaVersion)
        XCTAssertEqual(restored.decks.count, backup.decks.count)

        let decodedWord = restored.decks
            .flatMap(\.words)
            .first { $0.word == word.word }
        XCTAssertEqual(decodedWord?.reviewState?.intervalDays, 8)
        XCTAssertEqual(decodedWord?.reviewState?.lapses, 1)
    }

    func testRestoreSkipsExistingDecks() throws {
        let backup = try BackupService.makeBackup(context: context)
        let report = try BackupService.restore(backup, into: context)

        XCTAssertEqual(report.decks, 0)
        XCTAssertEqual(report.skippedDecks, backup.decks.count)
    }

    func testResetProgressClearsStates() throws {
        let word = try XCTUnwrap(try context.fetch(FetchDescriptor<Word>()).first)
        let state = ReviewState(wordID: word.id, deckID: word.deckID, phase: .review)
        context.insert(state)
        word.reviewState = state
        try context.save()

        try BackupService.resetProgress(context: context)

        let remaining = try context.fetch(FetchDescriptor<ReviewState>())
        XCTAssertTrue(remaining.isEmpty)
        let words = try context.fetch(FetchDescriptor<Word>())
        XCTAssertFalse(words.isEmpty, "重置进度不应该删词")
    }
}