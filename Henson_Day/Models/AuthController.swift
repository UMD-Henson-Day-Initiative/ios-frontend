import Foundation
import Supabase
import Combine

@MainActor
final class AuthController: ObservableObject {
    @Published private(set) var session: Session?
    @Published private(set) var isLoading = false
    @Published private(set) var infoMessage: String?
    @Published private(set) var errorMessage: String?

    private let client: SupabaseClient?
    private let redirectURL: URL?
    private var authListenerTask: Task<Void, Never>?

    var isAuthenticated: Bool {
        session != nil
    }

    var configurationError: String? {
        SupabaseClientProvider.configurationErrorDescription
    }

    init(
        client: SupabaseClient? = supabase,
        redirectURL: URL? = URL(string: "io.hensonday.app://login-callback")
    ) {
        self.client = client
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
    }

    func handleOpenURL(_ url: URL) async {
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
    }

    func signOut() async {
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
    }

    private func refreshSession() async {
        guard let client else {
            return
        }

        do {
            session = try await client.auth.session
        } catch {
            session = nil
        }
    }

    private func observeAuthStateChanges() async {
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
    }
}