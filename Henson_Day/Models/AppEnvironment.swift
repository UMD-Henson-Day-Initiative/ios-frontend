// AppEnvironment.swift

import Foundation

enum AppEnvironmentName: String {
    case development
    case staging
    case production
}

struct FeatureFlags {
    var useRemoteContent: Bool
    var enableRemoteCampusConfig: Bool
    var enableAnalytics: Bool
}

struct AppEnvironment {
    let name: AppEnvironmentName
    let apiBaseURL: URL
    let anonKey: String
    let contentVersion: String
    let featureFlags: FeatureFlags

    static let current: AppEnvironment = {
        #if DEBUG
        return .development
        #else
        return .production
        #endif
    }()

    static let development = AppEnvironment(
        name: .development,
        apiBaseURL: URL(string: "http://localhost:54321")!,
        anonKey: "",
        contentVersion: "1",
        featureFlags: FeatureFlags(
            useRemoteContent: false,
            enableRemoteCampusConfig: false,
            enableAnalytics: false
        )
    )

    static let staging = AppEnvironment(
        name: .staging,
        apiBaseURL: URL(string: "https://staging-api.hensonday.app")!,
        anonKey: "",
        contentVersion: "1",
        featureFlags: FeatureFlags(
            useRemoteContent: true,
            enableRemoteCampusConfig: true,
            enableAnalytics: true
        )
    )

    static let production = AppEnvironment(
        name: .production,
        apiBaseURL: URL(string: "https://api.hensonday.app")!,
        anonKey: "",
        contentVersion: "1",
        featureFlags: FeatureFlags(
            useRemoteContent: true,
            enableRemoteCampusConfig: true,
            enableAnalytics: true
        )
    )
}
