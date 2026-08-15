// AppEnvironment.swift
//
// Reads the app's backend configuration from Info.plist (set via the
// INFOPLIST_KEY_HENSON_* build settings in project.pbxproj, or overridable
// via process environment variables for local development/testing).

import Foundation

struct AppEnvironment {
    /// Supabase project URL, e.g. https://ysxejgyoitphtavtwcdd.supabase.co
    let supabaseURL: URL
    /// Supabase publishable (anon) key — safe for client-side use.
    let supabaseAnonKey: String
    /// Google iOS OAuth client ID, used to configure GoogleSignIn.
    let googleIOSClientID: String
    /// Base URL of the Flask backend (e.g. http://localhost:5000 for the
    /// simulator, or your Mac's LAN IP for a physical device during testing).
    let apiBaseURL: URL

    static let current: AppEnvironment = AppEnvironmentResolver.resolve()
}

private enum AppEnvironmentResolver {
    private static let supabaseURLKey = "HENSON_SUPABASE_URL"
    private static let anonKeyKey = "HENSON_ANON_KEY"
    private static let googleIOSClientIDKey = "HENSON_GOOGLE_IOS_CLIENT_ID"
    private static let apiBaseURLKey = "HENSON_API_BASE_URL"

    static func resolve(bundle: Bundle = .main, processInfo: ProcessInfo = .processInfo) -> AppEnvironment {
        let supabaseURLString = stringValue(for: supabaseURLKey, bundle: bundle, processInfo: processInfo) ?? ""
        let apiBaseURLString = stringValue(for: apiBaseURLKey, bundle: bundle, processInfo: processInfo) ?? ""

        guard let supabaseURL = URL(string: supabaseURLString), supabaseURL.scheme != nil else {
            fatalError("HENSON_SUPABASE_URL is missing or invalid in Info.plist — set it in project.pbxproj's INFOPLIST_KEY_HENSON_SUPABASE_URL.")
        }
        guard let apiBaseURL = URL(string: apiBaseURLString), apiBaseURL.scheme != nil else {
            fatalError("HENSON_API_BASE_URL is missing or invalid in Info.plist — set it in project.pbxproj's INFOPLIST_KEY_HENSON_API_BASE_URL.")
        }

        return AppEnvironment(
            supabaseURL: supabaseURL,
            supabaseAnonKey: stringValue(for: anonKeyKey, bundle: bundle, processInfo: processInfo) ?? "",
            googleIOSClientID: stringValue(for: googleIOSClientIDKey, bundle: bundle, processInfo: processInfo) ?? "",
            apiBaseURL: apiBaseURL
        )
    }

    private static func stringValue(for key: String, bundle: Bundle, processInfo: ProcessInfo) -> String? {
        if let processValue = processInfo.environment[key], !processValue.isEmpty {
            return processValue
        }
        guard let infoValue = bundle.object(forInfoDictionaryKey: key) as? String, !infoValue.isEmpty else {
            return nil
        }
        return infoValue
    }
}
