import Foundation

/// Data model for the authenticated Patreon user.
struct PatreonProfile: Codable {
    let id: String
    let displayName: String
    let avatarURL: String?
}

/// Static configuration for the Patreon OAuth 2.0 flow.
struct PatreonOAuthConfig {
    static let clientID = "[PATREON_CLIENT_ID]"
    static let clientSecret = "[PATREON_CLIENT_SECRET]"
    static let redirectURI = "JTopGames://oauth/callback"
    static let authorizeURL = "https://www.patreon.com/oauth2/authorize"
    static let tokenURL = "https://www.patreon.com/api/oauth2/token"
    static let identityURL = "https://www.patreon.com/api/oauth2/v2/identity"
    static let scopes = "identity"
}
