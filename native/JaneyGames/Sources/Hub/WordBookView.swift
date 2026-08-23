import SwiftUI

/// The Word Book: every word met across the games, searchable, with TTS.
struct WordBookView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""

    private var words: [LearnedWordRecord] {
        let all = model.wordBook.allWords(languageID: model.language.id)
        guard !searchText.isEmpty else { return all }
        return all.filter {
            $0.word.localizedStandardContains(searchText)
                || $0.translation.localizedStandardContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                let words = words
                if words.isEmpty {
                    ContentUnavailableView {
                        Label("Your Word Book is empty", systemImage: "character.book.closed")
                    } description: {
                        Text(searchText.isEmpty
                            ? "Every word you find in the games is collected here."
                            : "No words match your search.")
                    }
                } else {
                    List(words) { record in
                        WordBookRowView(record: record)
                            .listRowBackground(theme.surface.opacity(0.5))
                    }
                    .scrollContentBackground(.hidden)
                }
            }
            .background(theme.bgPrimary)
            .navigationTitle("Word Book · \(model.wordBook.wordCount(languageID: model.language.id))")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search words")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", action: { dismiss() })
                }
            }
        }
    }
}

struct WordBookRowView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.theme) private var theme
    let record: LearnedWordRecord

    private var sourceSymbol: String {
        GameID(rawValue: record.sourceGame)?.symbol ?? "gamecontroller"
    }

    var body: some View {
        HStack(spacing: Design.spacing) {
            Image(systemName: sourceSymbol)
                .font(.subheadline)
                .foregroundStyle(theme.textMuted)
                .frame(width: 24)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(record.word)
                    .font(.system(.body, design: .rounded))
                    .bold()
                    .foregroundStyle(theme.textPrimary)
                Text(record.translation)
                    .font(.subheadline)
                    .foregroundStyle(theme.info)
            }
            Spacer()
            if record.timesSeen > 1 {
                Text("×\(record.timesSeen)")
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(theme.textMuted)
                    .accessibilityLabel("Seen \(record.timesSeen) times")
            }
            if model.speech.hasVoice(for: model.language.id) {
                Button("Listen", systemImage: "speaker.wave.2", action: speak)
                    .labelStyle(.iconOnly)
                    .foregroundStyle(theme.accent)
                    .buttonStyle(.borderless)
            }
        }
        .padding(.vertical, 2)
    }

    private func speak() {
        model.speech.speak(record.word, languageID: model.language.id)
    }
}
