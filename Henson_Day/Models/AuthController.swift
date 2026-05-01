import Foundation
import Combine

#if canImport(Supabase)
import Supabase
typealias AuthSession = Session
typealias AuthClient = SupabaseClient
#else
struct AuthSession {}
typealias AuthClient = SupabaseAppClient
#endif

@MainActor
final class AuthController: ObservableObject {
    @Published private(set) var session: AuthSession?
    @Published private(set) var isLoading = false
    @Published private(set) var infoMessage: String?
    @Published private(set) var errorMessage: String?

    private let client: AuthClient?
    private let redirectURL: URL?
    private var authListenerTask: Task<Void, Never>?

    var isAuthenticated: Bool {
        session != nil
    }

    var configurationError: String? {
        SupabaseClientProvider.configurationErrorDescription
    }

    init(
        client: AuthClient? = nil,
        redirectURL: URL? = URL(string: "io.hensonday.app://login-callback")
    ) {
        self.client = client ?? supabase
        self.redirectURL = redirectURL

        Task {
            await refreshSession()
            await observeAuthStateChanges()
        }
    }

    deinit {
        authListenerTask?.cancel()
    }

    func signInWithMagicLink(email: String) async {
#if canImport(Supabase)
        guard let client else {
            errorMessage = configurationError ?? "Supabase is not configured yet."
            return
        }

        let normalized = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalized.isEmpty else {
            errorMessage = "Enter an email address to continue."
            return
        }

        isLoading = true
        errorMessage = nil
        infoMessage = nil

        defer { isLoading = false }

        do {
            try await client.auth.signInWithOTP(email: normalized, redirectTo: redirectURL)
            infoMessage = "Check your inbox for the sign-in link."
        } catch {
            errorMessage = error.localizedDescription
        }
#else
        errorMessage = configurationError ?? "Supabase SDK is not installed in this target."
#endif
    }

    func handleOpenURL(_ url: URL) async {
#if canImport(Supabase)
        guard let client else {
            return
        }

        do {
            let newSession = try await client.auth.session(from: url)
            session = newSession
            errorMessage = nil
            infoMessage = "Signed in successfully."
        } catch {
            errorMessage = error.localizedDescription
        }
#else
        _ = url
#endif
    }

    func signOut() async {
#if canImport(Supabase)
        guard let client else {
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            try await client.auth.signOut()
            session = nil
            infoMessage = "Signed out."
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
#else
        session = nil
        errorMessage = configurationError ?? "Supabase SDK is not installed in this target."
#endif
    }

    private func refreshSession() async {
#if canImport(Supabase)
        guard let client else {
            return
        }

        do {
            session = try await client.auth.session
        } catch {
            session = nil
        }
#else
        session = nil
#endif
    }

    private func observeAuthStateChanges() async {
#if canImport(Supabase)
        guard let client else {
            return
        }

        authListenerTask?.cancel()
        authListenerTask = Task { [weak self] in
            guard let self else { return }

            for await authState in client.auth.authStateChanges {
                if [.initialSession, .signedIn, .signedOut].contains(authState.event) {
                    self.session = authState.session
                }
            }
        }
#endif
    }
}