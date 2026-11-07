import AVFoundation

/// 系统 TTS 发音。离线可用，不联网。
///
/// 注意：`AVSpeechSynthesizer` 必须在主线程调用，所以整个类型标 `@MainActor`。
@MainActor
final class SpeechService {

    static let shared = SpeechService()

    private let synthesizer = AVSpeechSynthesizer()
    private var configured = false

    /// 当前口音（来自 AppSettings.voiceAccent）。
    var accent: VoiceAccent = .american

    private func configureSessionIfNeeded() {
        guard !configured else { return }
        configured = true
        let session = AVAudioSession.sharedInstance()
        // .ambient 不打断用户正在听的音乐；朗读单词够用了
        try? session.setCategory(.ambient, mode: .spokenAudio, options: [.duckOthers])
        try? session.setActive(true, options: [])
    }

    /// 朗读一个单词（或一句话）。
    func speak(_ text: String, accent: VoiceAccent? = nil) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        configureSessionIfNeeded()

        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }

        let utterance = AVSpeechUtterance(string: trimmed)
        let language = (accent ?? self.accent).languageCode
        utterance.voice = AVSpeechSynthesisVoice(language: language)
        utterance.rate = 0.45          // 默认偏快，学习场景慢一点
        utterance.pitchMultiplier = 1.0
        utterance.postUtteranceDelay = 0.05
        synthesizer.speak(utterance)
    }

    func stop() {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
    }
}