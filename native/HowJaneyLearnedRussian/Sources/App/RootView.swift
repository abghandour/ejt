import SwiftUI

struct RootView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var previousRankIndex: Int?
    @State private var rankCelebration: Rank?
    @State private var achievementCelebration: AchievementService.ID?
    @State private var pendingRankCelebration: Rank?

    var body: some View {
        @Bindable var model = model
        ZStack(alignment: .top) {
            HomeView()

            VStack(spacing: 10) {
                if let rankCelebration {
                    RankUpBannerView(rank: rankCelebration, dismiss: dismissRankCelebration)
                        .transition(reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity))
                }
                if let achievementCelebration {
                    AchievementStampView(achievement: achievementCelebration, dismiss: dismissAchievementCelebration)
                        .transition(reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity))
                }
            }
            .frame(maxWidth: 540)
            .padding(.horizontal, Design.padding)
            .padding(.top, 8)
            .zIndex(10)
        }
        .fullScreenCover(item: $model.activeGame) { game in
            switch game {
            case .bogglesky:
                BoggleskyView()
            case .triviatsky:
                TriviatskyView()
            case .scramblisky:
                ScramblisyView()
            case .rootsky:
                RootskyView()
            case .wordsky:
                RootskyView(gameID: .wordsky)
            case .snakesky:
                SnakeskyView()
            case .tetrisky:
                TetriskyView()
            case .slashsky:
                SlashskyView()
            case .meddleysky:
                MeddleyskyView()
            }
        }
        .sheet(isPresented: $model.isShowingSettings) {
            SettingsView()
        }
        .sheet(isPresented: $model.isShowingProfile) {
            ProfileView()
        }
        .sheet(isPresented: $model.isShowingWordBook) {
            WordBookView()
        }
        .sheet(isPresented: $model.isShowingPaywall) {
            PaywallView()
        }
        .environment(\.theme, model.theme)
        .environment(\.font, model.theme.bodyFontName.map { .custom($0, size: 17, relativeTo: .body) })
        .tint(model.theme.accent)
        .preferredColorScheme(model.theme.isDark ? .dark : .light)
        .onChange(of: scenePhase) {
            if scenePhase == .active {
                model.refreshStreakReminder()
            }
        }
        .onAppear {
            previousRankIndex = model.rank.index
        }
        .onChange(of: model.totalXP) { _, _ in
            let currentRank = model.rank
            if let previousRankIndex, currentRank.index > previousRankIndex {
                queueRankCelebration(currentRank)
            }
            previousRankIndex = currentRank.index
        }
        .onChange(of: model.achievements.unlockRevision) { _, _ in
            guard let achievement = model.achievements.latestUnlock else { return }
            queueAchievementCelebration(achievement)
        }
        .onChange(of: model.gameCenter.isAuthenticated) { _, isAuthenticated in
            guard isAuthenticated else { return }
            model.achievements.reportPendingToGameCenter()
        }
        .onChange(of: model.activeGame) { _, activeGame in
            guard activeGame == nil else { return }
            presentQueuedCelebrations()
        }
        .task {
            model.gameCenter.authenticate()
            model.refreshStreakReminder()
            let arguments = ProcessInfo.processInfo.arguments
            if let flag = arguments.firstIndex(of: "-language"), arguments.indices.contains(flag + 1) {
                model.settings.languageID = arguments[flag + 1]
            }
            for game in GameID.allCases where arguments.contains("-open-\(game.rawValue)") {
                model.activeGame = game
            }
            if arguments.contains("-open-profile") {
                model.isShowingProfile = true
            }
        }
    }

    private func presentRankCelebration(_ rank: Rank) {
        withAnimation(reduceMotion ? .linear(duration: 0) : Design.celebration) {
            rankCelebration = rank
        }
        Task {
            try? await Task.sleep(nanoseconds: 3_800_000_000)
            guard rankCelebration?.index == rank.index else { return }
            withAnimation(reduceMotion ? .linear(duration: 0) : Design.snappy) {
                rankCelebration = nil
            }
        }
    }

    private func queueRankCelebration(_ rank: Rank) {
        guard model.activeGame == nil else {
            pendingRankCelebration = rank
            return
        }
        presentRankCelebration(rank)
    }

    private func presentAchievementCelebration(_ achievement: AchievementService.ID) {
        withAnimation(reduceMotion ? .linear(duration: 0) : Design.celebration) {
            achievementCelebration = achievement
        }
        Task {
            try? await Task.sleep(nanoseconds: 4_600_000_000)
            guard achievementCelebration == achievement else { return }
            dismissAchievementCelebration()
        }
    }

    private func queueAchievementCelebration(_ achievement: AchievementService.ID) {
        guard model.activeGame == nil, achievementCelebration == nil else { return }
        presentAchievementCelebration(achievement)
    }

    private func presentQueuedCelebrations() {
        if let pendingRankCelebration {
            self.pendingRankCelebration = nil
            presentRankCelebration(pendingRankCelebration)
        }
        if achievementCelebration == nil, let nextAchievement = model.achievements.latestUnlock {
            presentAchievementCelebration(nextAchievement)
        }
    }

    private func dismissRankCelebration() {
        withAnimation(reduceMotion ? .linear(duration: 0) : Design.snappy) {
            rankCelebration = nil
        }
    }

    private func dismissAchievementCelebration() {
        withAnimation(reduceMotion ? .linear(duration: 0) : Design.snappy) {
            achievementCelebration = nil
        }
        model.achievements.dismissLatestUnlock()
    }
}
