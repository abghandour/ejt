import Foundation
import AuthenticationServices
import UIKit

/// Manages the full Patreon OAuth 2.0 authentication lifecycle.
///
/// Handles session checking, OAuth flow, token exchange/refresh,
/// user profile fetching, and logout. Stores tokens securely in the iOS Keychain.
///
/// Set `useMockAuth = true` to bypass real Patreon and use a simulated flow for testing.
@MainActor
class AuthManager: ObservableObject {

    // MARK: - Mock Mode

    /// Toggle this to `true` to use mock authentication (no real Patreon calls).
    /// Set to `false` for production builds with real Patreon OAuth.
    #if DEBUG
    var useMockAuth: Bool = true
    #else
    var useMockAuth: Bool = false
    #endif

    // MARK: - Published Properties

    @Published var isAuthenticated: Bool = false
    @Published var userProfile: PatreonProfile? = nil
    @Published var isLoading: Bool = true
    @Published var errorMessage: String? = nil

    // MARK: - Dependencies

    private let urlSession: URLSession

    init(urlSession: URLSession = .shared) {
        self.urlSession = urlSession
    }

    // MARK: - Session Check

    /// Loads tokens from Keychain, checks expiry, and sets `isAuthenticated`.
    /// If the token is expired, attempts a refresh. On failure, clears state.
    func checkExistingSession() async {
        isLoading = true
        errorMessage = nil

        defer { isLoading = false }

        // Mock mode: check if we previously "logged in" via mock
        if useMockAuth {
            if let tokenData = KeychainStore.load(key: KeychainStore.patreonAccessToken),
               !tokenData.isEmpty {
                isAuthenticated = true
                userProfile = MockAuthProvider.mockProfile
            } else {
                isAuthenticated = false
            }
            return
        }

        guard let tokenData = KeychainStore.load(key: KeychainStore.patreonAccessToken),
              !tokenData.isEmpty else {
            isAuthenticated = false
            return
        }

        if isTokenExpired() {
            do {
                try await refreshAccessToken()
            } catch {
                clearKeychainAndResetState()
                return
            }
        }

        isAuthenticated = true

        // Attempt to fetch profile; use fallback on failure
        do {
            try await fetchUserProfile()
        } catch {
            // Profile fetch is non-critical — proceed authenticated with no profile
        }
    }

    // MARK: - OAuth Flow

    /// Builds the Patreon authorize URL, presents `ASWebAuthenticationSession`,
    /// and extracts the authorization code from the callback.
    func startOAuthFlow() async throws {
        errorMessage = nil
        isLoading = true

        defer { isLoading = false }

        // Mock mode: simulate a 1-second OAuth flow, then authenticate
        if useMockAuth {
            try await MockAuthProvider.simulateOAuthFlow()
            userProfile = MockAuthProvider.mockProfile
            isAuthenticated = true
            return
        }

        guard var components = URLComponents(string: PatreonOAuthConfig.authorizeURL) else {
            throw AuthError.invalidURL
        }

        components.queryItems = [
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "client_id", value: PatreonOAuthConfig.clientID),
            URLQueryItem(name: "redirect_uri", value: PatreonOAuthConfig.redirectURI),
            URLQueryItem(name: "scope", value: PatreonOAuthConfig.scopes)
        ]

        guard let authorizeURL = components.url else {
            throw AuthError.invalidURL
        }

        let code: String = try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(
                url: authorizeURL,
                callbackURLScheme: "JTopGames"
            ) { callbackURL, error in
                if let error = error {
                    let nsError = error as NSError
                    if nsError.domain == ASWebAuthenticationSessionErrorDomain,
                       nsError.code == ASWebAuthenticationSessionError.canceledLogin.rawValue {
                        continuation.resume(throwing: AuthError.userCancelled)
                    } else {
                        continuation.resume(throwing: AuthError.oauthFailed(error.localizedDescription))
                    }
                    return
                }

                guard let callbackURL = callbackURL,
                      let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false),
                      let code = components.queryItems?.first(where: { $0.name == "code" })?.value else {
                    continuation.resume(throwing: AuthError.missingAuthCode)
                    return
                }

                continuation.resume(returning: code)
            }

            session.prefersEphemeralWebBrowserSession = false
            session.presentationContextProvider = PresentationContextProvider.shared

            if !session.start() {
                continuation.resume(throwing: AuthError.oauthFailed("Failed to start authentication session"))
            }
        }

        try await exchangeCodeForTokens(code: code)
        try await fetchUserProfile()
        isAuthenticated = true
    }

    // MARK: - Token Exchange

    /// POSTs to the Patreon token endpoint with the authorization code,
    /// parses the response, and stores tokens in Keychain.
    func exchangeCodeForTokens(code: String) async throws {
        guard let tokenURL = URL(string: PatreonOAuthConfig.tokenURL) else {
            throw AuthError.invalidURL
        }

        var request = URLRequest(url: tokenURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let bodyParams = [
            "code": code,
            "grant_type": "authorization_code",
            "client_id": PatreonOAuthConfig.clientID,
            "client_secret": PatreonOAuthConfig.clientSecret,
            "redirect_uri": PatreonOAuthConfig.redirectURI
        ]

        request.httpBody = bodyParams
            .map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? $0.value)" }
            .joined(separator: "&")
            .data(using: .utf8)

        let (data, response) = try await urlSession.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw AuthError.tokenExchangeFailed
        }

        try parseAndStoreTokens(from: data)
    }

    // MARK: - Token Refresh

    /// Uses the stored refresh token to obtain a new access token.
    /// Updates Keychain on success; clears state on failure.
    func refreshAccessToken() async throws {
        guard let refreshTokenData = KeychainStore.load(key: KeychainStore.patreonRefreshToken),
              let refreshToken = String(data: refreshTokenData, encoding: .utf8) else {
            throw AuthError.noRefreshToken
        }

        guard let tokenURL = URL(string: PatreonOAuthConfig.tokenURL) else {
            throw AuthError.invalidURL
        }

        var request = URLRequest(url: tokenURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let bodyParams = [
            "grant_type": "refresh_token",
            "refresh_token": refreshToken,
            "client_id": PatreonOAuthConfig.clientID,
            "client_secret": PatreonOAuthConfig.clientSecret
        ]

        request.httpBody = bodyParams
            .map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? $0.value)" }
            .joined(separator: "&")
            .data(using: .utf8)

        do {
            let (data, response) = try await urlSession.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                clearKeychainAndResetState()
                throw AuthError.tokenRefreshFailed
            }

            try parseAndStoreTokens(from: data)
        } catch let error as AuthError {
            throw error
        } catch {
            clearKeychainAndResetState()
            throw AuthError.tokenRefreshFailed
        }
    }

    // MARK: - User Profile

    /// GETs the Patreon identity endpoint and parses the response into a `PatreonProfile`.
    func fetchUserProfile() async throws {
        guard let accessTokenData = KeychainStore.load(key: KeychainStore.patreonAccessToken),
              let accessToken = String(data: accessTokenData, encoding: .utf8) else {
            throw AuthError.noAccessToken
        }

        guard var components = URLComponents(string: PatreonOAuthConfig.identityURL) else {
            throw AuthError.invalidURL
        }

        components.queryItems = [
            URLQueryItem(name: "fields[user]", value: "full_name,image_url")
        ]

        guard let identityURL = components.url else {
            throw AuthError.invalidURL
        }

        var request = URLRequest(url: identityURL)
        request.httpMethod = "GET"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await urlSession.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw AuthError.profileFetchFailed
        }

        userProfile = try parsePatreonIdentityResponse(data: data)
    }

    // MARK: - Logout

    /// Clears all Keychain entries and resets published properties.
    func logout() {
        clearKeychainAndResetState()
        userProfile = nil
    }


    // MARK: - Private Helpers

    /// Checks whether the stored token expiry timestamp is in the past.
    private func isTokenExpired() -> Bool {
        guard let expiryData = KeychainStore.load(key: KeychainStore.patreonTokenExpiry),
              let expiryString = String(data: expiryData, encoding: .utf8),
              let expiryTimestamp = TimeInterval(expiryString) else {
            // No expiry stored — treat as expired to force refresh
            return true
        }

        return Date().timeIntervalSince1970 >= expiryTimestamp
    }

    /// Parses the Patreon token response JSON and stores tokens + expiry in Keychain.
    private func parseAndStoreTokens(from data: Data) throws {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let accessToken = json["access_token"] as? String,
              let refreshToken = json["refresh_token"] as? String else {
            throw AuthError.invalidTokenResponse
        }

        // Store access token
        guard let accessTokenData = accessToken.data(using: .utf8) else {
            throw AuthError.invalidTokenResponse
        }
        KeychainStore.save(key: KeychainStore.patreonAccessToken, data: accessTokenData)

        // Store refresh token
        guard let refreshTokenData = refreshToken.data(using: .utf8) else {
            throw AuthError.invalidTokenResponse
        }
        KeychainStore.save(key: KeychainStore.patreonRefreshToken, data: refreshTokenData)

        // Store expiry timestamp (current time + expires_in seconds)
        let expiresIn = json["expires_in"] as? TimeInterval ?? 2592000 // Default 30 days
        let expiryTimestamp = Date().timeIntervalSince1970 + expiresIn
        let expiryString = String(expiryTimestamp)
        if let expiryData = expiryString.data(using: .utf8) {
            KeychainStore.save(key: KeychainStore.patreonTokenExpiry, data: expiryData)
        }
    }

    /// Parses the Patreon API v2 identity response into a `PatreonProfile`.
    ///
    /// Expected format:
    /// ```json
    /// {
    ///   "data": {
    ///     "id": "12345",
    ///     "attributes": {
    ///       "full_name": "John Doe",
    ///       "image_url": "https://..."
    ///     }
    ///   }
    /// }
    /// ```
    private func parsePatreonIdentityResponse(data: Data) throws -> PatreonProfile {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let dataObj = json["data"] as? [String: Any],
              let id = dataObj["id"] as? String else {
            throw AuthError.invalidProfileResponse
        }

        let attributes = dataObj["attributes"] as? [String: Any]
        let displayName = attributes?["full_name"] as? String ?? "Player"
        let avatarURL = attributes?["image_url"] as? String

        return PatreonProfile(id: id, displayName: displayName, avatarURL: avatarURL)
    }

    /// Deletes all token entries from Keychain and sets `isAuthenticated` to false.
    private func clearKeychainAndResetState() {
        KeychainStore.delete(key: KeychainStore.patreonAccessToken)
        KeychainStore.delete(key: KeychainStore.patreonRefreshToken)
        KeychainStore.delete(key: KeychainStore.patreonTokenExpiry)
        isAuthenticated = false
    }
}

// MARK: - Auth Errors

/// Errors that can occur during the authentication flow.
enum AuthError: LocalizedError {
    case invalidURL
    case userCancelled
    case oauthFailed(String)
    case missingAuthCode
    case tokenExchangeFailed
    case tokenRefreshFailed
    case noRefreshToken
    case noAccessToken
    case invalidTokenResponse
    case profileFetchFailed
    case invalidProfileResponse

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid authentication URL."
        case .userCancelled:
            return "Login was cancelled."
        case .oauthFailed(let message):
            return "Authentication failed: \(message)"
        case .missingAuthCode:
            return "No authorization code received from Patreon."
        case .tokenExchangeFailed:
            return "Failed to exchange authorization code for tokens."
        case .tokenRefreshFailed:
            return "Session expired. Please log in again."
        case .noRefreshToken:
            return "No refresh token available. Please log in again."
        case .noAccessToken:
            return "No access token available. Please log in again."
        case .invalidTokenResponse:
            return "Received an invalid response from Patreon."
        case .profileFetchFailed:
            return "Failed to load your Patreon profile."
        case .invalidProfileResponse:
            return "Received an invalid profile response from Patreon."
        }
    }
}

// MARK: - ASWebAuthenticationSession Presentation Context

// MARK: - ASWebAuthenticationSession Presentation Context

/// Provides the presentation anchor for `ASWebAuthenticationSession`.
private class PresentationContextProvider: NSObject, ASWebAuthenticationPresentationContextProviding {
    static let shared = PresentationContextProvider()

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        guard let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first,
              let window = windowScene.windows.first else {
            return ASPresentationAnchor()
        }
        return window
    }
}

// MARK: - Mock Auth Provider

/// Simulates the Patreon OAuth API for local testing without real credentials.
/// Mimics the same flow (delay for "network", fake tokens, fake profile) so the
/// rest of the app behaves identically to a real Patreon session.
enum MockAuthProvider {

    /// The mock user profile returned after "login".
    static let mockProfile = PatreonProfile(
        id: "mock-12345",
        displayName: "Test Patron",
        avatarURL: nil
    )

    /// Simulates the full OAuth flow: authorization → token exchange → profile fetch.
    /// Stores fake tokens in Keychain so session persistence works normally.
    static func simulateOAuthFlow() async throws {
        // Simulate network latency for the authorization screen
        try await Task.sleep(nanoseconds: 800_000_000) // 0.8s

        // Simulate token exchange — store fake tokens in Keychain
        let fakeTokenResponse: [String: Any] = [
            "access_token": "mock_access_token_\(UUID().uuidString)",
            "refresh_token": "mock_refresh_token_\(UUID().uuidString)",
            "expires_in": 2592000, // 30 days
            "token_type": "Bearer",
            "scope": "identity"
        ]

        guard let accessToken = fakeTokenResponse["access_token"] as? String,
              let refreshToken = fakeTokenResponse["refresh_token"] as? String,
              let accessData = accessToken.data(using: .utf8),
              let refreshData = refreshToken.data(using: .utf8) else {
            throw AuthError.invalidTokenResponse
        }

        KeychainStore.save(key: KeychainStore.patreonAccessToken, data: accessData)
        KeychainStore.save(key: KeychainStore.patreonRefreshToken, data: refreshData)

        let expiresIn = fakeTokenResponse["expires_in"] as? TimeInterval ?? 2592000
        let expiryTimestamp = Date().timeIntervalSince1970 + expiresIn
        if let expiryData = String(expiryTimestamp).data(using: .utf8) {
            KeychainStore.save(key: KeychainStore.patreonTokenExpiry, data: expiryData)
        }

        // Simulate profile fetch latency
        try await Task.sleep(nanoseconds: 300_000_000) // 0.3s
    }

    /// Returns a mock Patreon API v2 identity response as Data,
    /// matching the real API format for testing the parser.
    static func mockIdentityResponseData() -> Data {
        let json: [String: Any] = [
            "data": [
                "id": mockProfile.id,
                "type": "user",
                "attributes": [
                    "full_name": mockProfile.displayName,
                    "image_url": mockProfile.avatarURL as Any
                ]
            ]
        ]
        return (try? JSONSerialization.data(withJSONObject: json)) ?? Data()
    }

    /// Returns a mock token response as Data, matching the real Patreon token endpoint format.
    static func mockTokenResponseData() -> Data {
        let json: [String: Any] = [
            "access_token": "mock_access_\(UUID().uuidString)",
            "refresh_token": "mock_refresh_\(UUID().uuidString)",
            "expires_in": 2592000,
            "token_type": "Bearer",
            "scope": "identity"
        ]
        return (try? JSONSerialization.data(withJSONObject: json)) ?? Data()
    }
}
