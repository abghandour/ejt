import SwiftUI

struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                if FeatureFlags.multiLanguage {
                    Section("Language") {
                        ForEach(model.languages) { language in
                            LanguageRowView(language: language)
                        }
                    }
                }

                Section("Theme") {
                    ThemeGridView()
                }

                Section("Feedback") {
                    Toggle("Sounds", systemImage: "speaker.wave.2", isOn: soundBinding)
                    Toggle("Haptics", systemImage: "hand.tap", isOn: hapticsBinding)
                }

                Section("Premium") {
                    if model.store.isPremium {
                        Label("Premium active", systemImage: "checkmark.seal.fill")
                            .foregroundStyle(theme.success)
                    } else {
                        Button("Unlock Premium", systemImage: "sparkles", action: showPaywall)
                    }
                    Button("Restore Purchases", action: restore)
                }

                Section {
                    LabeledContent("Version", value: appVersion)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", action: { dismiss() })
                }
            }
        }
    }

    private var soundBinding: Binding<Bool> {
        Binding(
            get: { model.settings.soundEnabled },
            set: { model.setSoundEnabled($0) }
        )
    }

    private var hapticsBinding: Binding<Bool> {
        @Bindable var settings = model.settings
        return $settings.hapticsEnabled
    }

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }

    private func showPaywall() {
        model.isShowingPaywall = true
    }

    private func restore() {
        Task { await model.store.restorePurchases() }
    }
}

/// One selectable language row with lock state for non-premium users.
struct LanguageRowView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.theme) private var theme
    let language: Language

    var body: some View {
        Button(action: select) {
            HStack {
                Text(language.flag)
                Text(language.displayName)
                    .foregroundStyle(theme.textPrimary)
                Spacer()
                if model.isLanguageLocked(language) {
                    Image(systemName: "lock.fill")
                        .foregroundStyle(theme.textMuted)
                        .accessibilityLabel("Requires Premium")
                } else if language.id == model.language.id {
                    Image(systemName: "checkmark")
                        .foregroundStyle(theme.accent)
                        .accessibilityLabel("Selected")
                }
            }
        }
    }

    private func select() {
        model.selectLanguage(language)
    }
}
