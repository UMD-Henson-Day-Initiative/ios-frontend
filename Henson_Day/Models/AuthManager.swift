import Foundation
import Combine
import Supabase
import GoogleSignIn
import UIKit

/// Wraps Supabase Auth + native Google sign-in. Sign-in itself is entirely
/// client-side: GoogleSignIn gets an ID token, Supabase exchanges it for a
/// session. The backend never sees a Google credential directly — it only
/// verifies the resulting Supabase session JWT (see backend/henson-backend/app/auth.py).
@MainActor
final class AuthManager: ObservableObject {
    @Published private(set) var session: Session?
    @Published private(set) var isRestoringSession = true
    @Published var lastErrorMessage: String?

    let client: SupabaseClient

    private var authStateTask: Task<Void, Never>?

    init(environment: AppEnvironment = .current) {
        client = SupabaseClient(supabaseURL: environment.supabaseURL, supabaseKey: environment.supabaseAnonKey)
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: environment.googleIOSClientID)
        observeAuthState()
    }

    var accessToken: String? { session?.accessToken }
    var currentUserEmail: String? { session?.user.email }

    private func observeAuthState() {
        authStateTask = Task { [weak self] in
            guard let self else { return }
            for await (_, session) in client.auth.authStateChanges {
                self.session = session
                self.isRestoringSession = false
            }
        }
    }

    func signInWithGoogle() async {
        lastErrorMessage = nil
        guard let presentingVC = Self.topViewController() else {
            lastErrorMessage = "Couldn't find a screen to present sign-in from."
            return
        }

        do {
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: presentingVC)
            guard let idToken = result.user.idToken?.tokenString else {
                lastErrorMessage = "Google didn't return a sign-in token."
                return
            }
            try await client.auth.signInWithIdToken(
                credentials: OpenIDConnectCredentials(provider: .google, idToken: idToken)
            )
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    func signOut() async {
        GIDSignIn.sharedInstance.signOut()
        try? await client.auth.signOut()
    }

    /// Forward the OAuth callback URL to GoogleSignIn — call from `.onOpenURL`.
    static func handle(url: URL) {
        GIDSignIn.sharedInstance.handle(url)
    }

    private static func topViewController(base: UIViewController? = nil) -> UIViewController? {
        let base = base ?? UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }?
            .rootViewController

        if let nav = base as? UINavigationController {
            return topViewController(base: nav.visibleViewController)
        }
        if let tab = base as? UITabBarController, let selected = tab.selectedViewController {
            return topViewController(base: selected)
        }
        if let presented = base?.presentedViewController {
            return topViewController(base: presented)
        }
        return base
    }
}
