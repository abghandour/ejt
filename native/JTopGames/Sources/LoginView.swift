import SwiftUI

/// Login screen with Soviet propaganda-inspired styling.
/// Displays the app title, a sunburst pattern background, and a Patreon login button.
/// Shows error messages with retry when authentication fails.
struct LoginView: View {
    @EnvironmentObject var authManager: AuthManager

    var body: some View {
        ZStack {
            // Dark background
            Color(hex: "0e0e1a")
                .ignoresSafeArea()

            // Sunburst pattern overlay
            SunburstView()
                .ignoresSafeArea()

            // Main content
            VStack(spacing: 32) {
                Spacer()

                // App title
                VStack(spacing: 8) {
                    Text("How Janey Learned Russian")
                        .font(.custom("RobotoCondensed-Bold", size: 64))
                        .foregroundColor(Color(hex: "c8a830"))
                        .tracking(8)

                    Text("GAMES")
                        .font(.custom("RobotoCondensed-Bold", size: 36))
                        .foregroundColor(Color(hex: "f5e6c8"))
                        .tracking(12)
                }

                // Decorative star
                Image(systemName: "star.fill")
                    .font(.system(size: 28))
                    .foregroundColor(Color(hex: "c8a830"))

                Spacer()

                // Error message display
                if let errorMessage = authManager.errorMessage {
                    VStack(spacing: 12) {
                        Text(errorMessage)
                            .font(.custom("RobotoCondensed-Regular", size: 14))
                            .foregroundColor(Color.red.opacity(0.9))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)

                        Button {
                            Task {
                                try? await authManager.startOAuthFlow()
                            }
                        } label: {
                            Text("RETRY")
                                .font(.custom("RobotoCondensed-Bold", size: 14))
                                .foregroundColor(Color(hex: "c8a830"))
                                .padding(.horizontal, 24)
                                .padding(.vertical, 8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 4)
                                        .stroke(Color(hex: "c8a830"), lineWidth: 1)
                                )
                        }
                        .accessibilityLabel("Retry login")
                    }
                    .padding(.bottom, 8)
                }

                // Patreon login button
                Button {
                    Task {
                        try? await authManager.startOAuthFlow()
                    }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "person.badge.key.fill")
                            .font(.system(size: 18))
                        Text("LOGIN WITH PATREON")
                            .font(.custom("RobotoCondensed-Bold", size: 18))
                            .tracking(2)
                    }
                    .foregroundColor(Color(hex: "0e0e1a"))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color(hex: "c8a830"))
                    .cornerRadius(8)
                    .padding(.horizontal, 40)
                }
                .accessibilityLabel("Login with Patreon")
                .disabled(authManager.isLoading)
                .opacity(authManager.isLoading ? 0.5 : 1.0)

                Spacer()
                    .frame(height: 60)
            }
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Sunburst Pattern

/// A radial sunburst pattern drawn with a conic gradient,
/// evoking Soviet propaganda poster aesthetics.
struct SunburstView: View {
    var body: some View {
        GeometryReader { geometry in
            let center = CGPoint(
                x: geometry.size.width / 2,
                y: geometry.size.height * 0.35
            )

            let rayCount = 24
            var stops: [Gradient.Stop] = []

            // Build alternating ray stops
            let _ = {
                for i in 0..<rayCount {
                    let fraction = Double(i) / Double(rayCount)
                    let nextFraction = Double(i + 1) / Double(rayCount)
                    let midFraction = (fraction + nextFraction) / 2

                    let darkColor = Color(hex: "0e0e1a")
                    let lightColor = Color(hex: "c8a830").opacity(0.06)

                    stops.append(Gradient.Stop(color: darkColor, location: fraction))
                    stops.append(Gradient.Stop(color: lightColor, location: midFraction))
                }
            }()

            AngularGradient(
                gradient: Gradient(stops: stops),
                center: UnitPoint(
                    x: center.x / geometry.size.width,
                    y: center.y / geometry.size.height
                )
            )
            .opacity(0.8)
        }
    }
}
