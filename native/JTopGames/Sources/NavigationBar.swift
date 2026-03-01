import SwiftUI

/// Persistent top navigation bar with horizontally scrollable game tabs
/// and a profile button with logout menu. Uses the Soviet propaganda aesthetic
/// with dark background, gold accents, and cream text.
struct NavigationBar: View {
    @Binding var selectedGame: GameDefinition
    @EnvironmentObject var authManager: AuthManager

    var body: some View {
        HStack(spacing: 0) {
            // Horizontally scrollable game tabs
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 20) {
                    ForEach(GameRegistry.games) { game in
                        GameTab(
                            game: game,
                            isActive: game.id == selectedGame.id,
                            onTap: { selectedGame = game }
                        )
                    }
                }
                .padding(.horizontal, 16)
            }

            // Profile button with logout menu
            ProfileButton(authManager: authManager)
                .padding(.trailing, 12)
        }
        .frame(height: 56)
        .background(Color(hex: "0e0e1a"))
    }
}

// MARK: - Game Tab

/// A single game tab showing the game icon and display name.
/// Active tab is highlighted with a gold underline.
private struct GameTab: View {
    let game: GameDefinition
    let isActive: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: game.iconName)
                        .font(.system(size: 16))
                        .frame(width: 20, height: 20)

                    Text(game.displayName)
                        .font(.custom("RobotoCondensed-Regular", size: 14))
                        .foregroundColor(Color(hex: "f5e6c8"))
                }

                // Gold underline for active tab
                Rectangle()
                    .fill(isActive ? Color(hex: "c8a830") : Color.clear)
                    .frame(height: 2)
            }
        }
        .accessibilityLabel("\(game.displayName) game tab")
        .accessibilityAddTraits(isActive ? .isSelected : [])
    }
}

// MARK: - Profile Button

/// Displays the authenticated user's Patreon display name or avatar.
/// Tapping presents a menu with a logout option.
private struct ProfileButton: View {
    @ObservedObject var authManager: AuthManager

    var body: some View {
        Menu {
            Button(role: .destructive) {
                authManager.logout()
            } label: {
                Label("Logout", systemImage: "rectangle.portrait.and.arrow.right")
            }
        } label: {
            if let profile = authManager.userProfile {
                Text(profile.displayName)
                    .font(.custom("RobotoCondensed-Regular", size: 13))
                    .foregroundColor(Color(hex: "f5e6c8"))
                    .lineLimit(1)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.white.opacity(0.08))
                    )
            } else {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(Color(hex: "f5e6c8"))
            }
        }
        .accessibilityLabel("Profile menu")
    }
}
