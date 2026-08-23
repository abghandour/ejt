import AVFoundation
import Observation

/// Pronounces target-language words with the system voice, replacing the web
/// SpeechSynthesis TTS. The speaker button only appears when a voice exists.
@Observable
final class SpeechService {
    @ObservationIgnored private let synthesizer = AVSpeechSynthesizer()

    /// BCP-47 voice language for a game language id.
    nonisolated static func voiceLanguage(for languageID: String) -> String {
        switch languageID {
        case "ru": "ru-RU"
        case "uk": "uk-UA"
        case "pt-br": "pt-BR"
        default: languageID
        }
    }

    func hasVoice(for languageID: String) -> Bool {
        let code = Self.voiceLanguage(for: languageID)
        return AVSpeechSynthesisVoice.speechVoices().contains {
            $0.language.compare(code, options: .caseInsensitive) == .orderedSame
        }
    }

    func speak(_ text: String, languageID: String) {
        synthesizer.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: Self.voiceLanguage(for: languageID))
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.9
        synthesizer.speak(utterance)
    }
}
