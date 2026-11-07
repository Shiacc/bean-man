import SwiftUI

/// 小动物 + 气泡：今日页顶部、空状态、完成页都用它。
///
/// 布局：动物在左，气泡在右，气泡尾巴指向动物。
/// 动物缺席（素材还没画）时 AnimalView 会自动走占位图，不会破版。
struct CompanionBubble: View {
    var animal: Animal
    var line: String
    var detail: String?
    var expression: AnimalExpression = .normal
    var tone: BubbleTone = .brand
    var animalSize: CGFloat = 84
    var onTap: (() -> Void)?

    var body: some View {
        HStack(alignment: .bottom, spacing: -2) {
            AnimalView(animal: animal, size: animalSize, expression: expression)
                .offset(y: 6)

            XiaodouSpeech(
                line: line,
                detail: detail,
                tone: tone,
                edge: .leading,
                onTap: onTap
            )
            .padding(.leading, 6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(animal.displayName)：\(line)\(detail.map { "。\($0)" } ?? "")")
    }
}

#Preview("橘子 · 说一句话") {
    VStack(spacing: 28) {
        CompanionBubble(
            animal: .juzi,
            line: "12 个到期词，先清一波？",
            detail: "先清到期，再学 20 个新词"
        )
        CompanionBubble(
            animal: .juzi,
            line: "这个记住了",
            expression: .happy,
            tone: .success
        )
        CompanionBubble(
            animal: .juzi,
            line: "还有 20 个没看，慢慢来",
            expression: .blink,
            tone: .warning
        )
    }
    .padding(20)
    .background(Theme.Palette.bg)
}