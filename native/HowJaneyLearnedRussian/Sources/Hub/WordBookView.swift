import SwiftUI

/// A living field journal: it keeps the player's discoveries useful by
/// surfacing a gentle review prompt before the full collection.
struct WordBookView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""

    private var words: [LearnedWordRecord] {
        _ = model.wordBook.revision
        let all = model.wordBook.allWords(languageID: model.language.id)
        guard !searchText.isEmpty else { return all }
        return all.filter {
            $0.word.localizedStandardContains(searchText)
                || $0.translation.localizedStandardContains(searchText)
        }
    }

    private var reviewCandidate: LearnedWordRecord? {
        guard searchText.isEmpty else { return nil }
        return model.wordBook.reviewCandidate(languageID: model.language.id)
    }

    var body: some View {
        let words = words
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    WordBookJournalHeader(wordCount: model.wordBook.wordCount(languageID: model.language.id))

                    if let reviewCandidate {
                        JournalReviewPromptView(record: reviewCandidate)
                            .id(reviewCandidate.word)
                    }

                    Text(searchText.isEmpty ? "YOUR DISCOVERIES" : "SEARCH RESULTS")
                        .font(.caption.weight(.black))
                        .tracking(1.1)
                        .foregroundStyle(theme.textSecondary)
                        .padding(.horizontal, 2)

                    if words.isEmpty {
                        ContentUnavailableView {
                            Label("Your Word Book is empty", systemImage: "character.book.closed")
                        } description: {
                            Text(searchText.isEmpty
                                ? "Every word you find in the games is collected here."
                                : "No words match your search.")
                        }
                        .frame(maxWidth: .infinity, minHeight: 260)
                    } else {
                        LazyVStack(spacing: 10) {
                            ForEach(words) { record in
                                WordBookRowView(record: record)
                            }
                        }
                    }
                }
                .frame(maxWidth: Design.maxContentWidth, alignment: .leading)
                .padding(Design.padding)
                .padding(.bottom, 32)
            }
            .scrollIndicators(.hidden)
            .background(theme.bgPrimary)
            .navigationTitle("Field Journal")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search words or meanings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", action: { dismiss() })
                }
            }
        }
    }
}

struct WordBookJournalHeader: View {
    @Environment(AppModel.self) private var model
    @Environment(\.theme) private var theme
    let wordCount: Int

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            Image(systemName: "character.book.closed.fill")
                .font(.title2.weight(.black))
                .foregroundStyle(theme.accent)
                .frame(width: 52, height: 52)
                .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(theme.accent.opacity(0.14)))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text("\(wordCount) WORD\(wordCount == 1 ? "" : "S") SAFE")
                    .font(.caption.weight(.black))
                    .tracking(1.1)
                    .foregroundStyle(theme.textSecondary)
                Text("A notebook for \(model.language.displayName) discoveries.")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(theme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .expeditionPanel()
    }
}

struct JournalReviewPromptView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.theme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let record: LearnedWordRecord
    @State private var isTranslationVisible = false
    @State private var hasRecordedReview = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("ONE MORE LOOK", systemImage: "arrow.clockwise.circle.fill")
                    .font(.caption.weight(.black))
                    .tracking(1.1)
                    .foregroundStyle(theme.accent)
                Spacer()
                Text(record.timesSeen == 1 ? "NEW" : "SEEN ×\(record.timesSeen)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(theme.textMuted)
            }

            Text(record.word)
                .heading(.title, kerning: 0.2)
                .foregroundStyle(theme.textPrimary)

            if isTranslationVisible {
                Text(record.translation.isEmpty ? "No translation recorded yet." : record.translation)
                    .font(.body.weight(.medium))
                    .foregroundStyle(theme.info)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            } else {
                Text("Can you remember what it means?")
                    .font(.subheadline)
                    .foregroundStyle(theme.textSecondary)
            }

            HStack(spacing: 10) {
                Button(isTranslationVisible ? "Hide meaning" : "Reveal meaning") {
                    // Record the review only once the meaning has been seen and
                    // hidden again: recording on reveal bumps timesSeen, which
                    // picks a new candidate and replaces this card (via `.id`)
                    // before the translation is ever shown.
                    if isTranslationVisible {
                        recordReview()
                    }
                    withAnimation(reduceMotion ? .linear(duration: 0) : Design.snappy) {
                        isTranslationVisible.toggle()
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(theme.accent)

                if model.speech.hasVoice(for: model.language.id) {
                    Button("Listen", systemImage: "speaker.wave.2") {
                        model.speech.speak(record.word, languageID: model.language.id)
                    }
                    .buttonStyle(.bordered)
                    .tint(theme.accent)
                }
            }
        }
        .expeditionPanel()
        .accessibilityElement(children: .contain)
        .onDisappear {
            if isTranslationVisible {
                recordReview()
            }
        }
    }

    private func recordReview() {
        guard !hasRecordedReview else { return }
        hasRecordedReview = true
        model.wordBook.markReviewed(record)
    }
}

struct WordBookRowView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.theme) private var theme
    let record: LearnedWordRecord

    private var sourceGame: GameID? {
        GameID(rawValue: record.sourceGame)
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: sourceGame?.symbol ?? "gamecontroller.fill")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(theme.accent)
                .frame(width: 34, height: 34)
                .background(Circle().fill(theme.accent.opacity(0.13)))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(record.word)
                    .font(.system(.body, design: .rounded).weight(.bold))
                    .foregroundStyle(theme.textPrimary)
                Text(record.translation.isEmpty ? "Meaning waiting to be found" : record.translation)
                    .font(.subheadline)
                    .foregroundStyle(record.translation.isEmpty ? theme.textMuted : theme.info)
                Text("FROM \((sourceGame?.rawValue ?? "FIELD NOTE").uppercased()) · SEEN \(record.timesSeen)×")
                    .font(.caption2.weight(.bold))
                    .tracking(0.6)
                    .foregroundStyle(theme.textMuted)
            }

            Spacer(minLength: 4)

            if model.speech.hasVoice(for: model.language.id) {
                Button("Listen", systemImage: "speaker.wave.2") {
                    model.speech.speak(record.word, languageID: model.language.id)
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.plain)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(theme.accent)
                .frame(width: 44, height: 44)
                .background(Circle().fill(theme.accent.opacity(0.12)))
                .accessibilityLabel("Listen to \(record.word)")
            }
        }
        .expeditionPanel()
        .accessibilityElement(children: .contain)
    }
}
