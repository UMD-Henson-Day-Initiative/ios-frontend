// AppEnvironment.swift

import Foundation

enum AppEnvironmentName: String {
    case development
    case staging
    case production

    static func resolve(from rawValue: String?) -> AppEnvironmentName {
        guard let rawValue else { return defaultForBuildConfiguration }
        return AppEnvironmentName(rawValue: rawValue.lowercased()) ?? defaultForBuildConfiguration
    }

    private static var defaultForBuildConfiguration: AppEnvironmentName {
        #if DEBUG
        return .development
        #else
        return .production
        #endif
    }
}

struct FeatureFlags {
    var useRemoteContent: Bool
    var enableRemoteCampusConfig: Bool
    var enableAnalytics: Bool
}

enum AppEnvironmentConfigurationIssue: Equatable {
    case missingAnonKey
    case invalidAPIBaseURL(String)
    case remoteCampusConfigRequiresRemoteContent

    var message: String {
        switch self {
        case .missingAnonKey:
            return "No anon key is configured. Requests will run without an Authorization header."
        case .invalidAPIBaseURL(let urlString):
            return "Remote content is disabled because the API base URL is invalid: \(urlString)"
        case .remoteCampusConfigRequiresRemoteContent:
            return "Remote campus config is disabled because remote content is off."
        }
    }
}

struct AppEnvironment {
    let name: AppEnvironmentName
    let apiBaseURL: URL
    let anonKey: String
    let contentVersion: String
    let featureFlags: FeatureFlags
    let configurationIssues: [AppEnvironmentConfigurationIssue]

    static let current: AppEnvironment = AppEnvironmentResolver.resolve()

    var remoteContentDisabledReason: String? {
        configurationIssues.first?.message
    }

    var usesRemoteContent: Bool {
        featureFlags.useRemoteContent
    }

    static let development = AppEnvironment(
        name: .development,
        apiBaseURL: URL(string: "http://localhost:54321")!,
        anonKey: "",
        contentVersion: "1",
        featureFlags: FeatureFlags(
            useRemoteContent: false,
            enableRemoteCampusConfig: false,
            enableAnalytics: false
        ),
        configurationIssues: []
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
        ),
        configurationIssues: []
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
        ),
        configurationIssues: []
    )
}

private enum AppEnvironmentResolver {
    private static let environmentNameKey = "HENSON_ENVIRONMENT"
    private static let apiBaseURLKey = "HENSON_API_BASE_URL"
    private static let anonKeyKey = "HENSON_ANON_KEY"
    private static let contentVersionKey = "HENSON_CONTENT_VERSION"
    private static let remoteContentFlagKey = "HENSON_USE_REMOTE_CONTENT"
    private static let remoteCampusConfigFlagKey = "HENSON_ENABLE_REMOTE_CAMPUS_CONFIG"
    private static let analyticsFlagKey = "HENSON_ENABLE_ANALYTICS"

    static func resolve(bundle: Bundle = .main, processInfo: ProcessInfo = .processInfo) -> AppEnvironment {
        let environmentName = AppEnvironmentName.resolve(from: stringValue(for: environmentNameKey, bundle: bundle, processInfo: processInfo))
        let defaults = defaultsForEnvironment(environmentName)

        let configuredBaseURLString = stringValue(for: apiBaseURLKey, bundle: bundle, processInfo: processInfo)
        let configuredAnonKey = stringValue(for: anonKeyKey, bundle: bundle, processInfo: processInfo) ?? defaults.anonKey
        let configuredContentVersion = stringValue(for: contentVersionKey, bundle: bundle, processInfo: processInfo) ?? defaults.contentVersion

        var featureFlags = defaults.featureFlags
        featureFlags.useRemoteContent = boolValue(for: remoteContentFlagKey, bundle: bundle, processInfo: processInfo) ?? featureFlags.useRemoteContent
        featureFlags.enableRemoteCampusConfig = boolValue(for: remoteCampusConfigFlagKey, bundle: bundle, processInfo: processInfo) ?? featureFlags.enableRemoteCampusConfig
        featureFlags.enableAnalytics = boolValue(for: analyticsFlagKey, bundle: bundle, processInfo: processInfo) ?? featureFlags.enableAnalytics

        let baseURLString = configuredBaseURLString ?? defaults.apiBaseURL.absoluteString
        var issues: [AppEnvironmentConfigurationIssue] = []

        guard let apiBaseURL = URL(string: baseURLString), apiBaseURL.scheme != nil else {
            issues.append(.invalidAPIBaseURL(baseURLString))
            return AppEnvironment(
                name: environmentName,
                apiBaseURL: defaults.apiBaseURL,
                anonKey: configuredAnonKey,
                contentVersion: configuredContentVersion,
                featureFlags: FeatureFlags(
                    useRemoteContent: false,
                    enableRemoteCampusConfig: false,
                    enableAnalytics: featureFlags.enableAnalytics
                ),
                configurationIssues: issues
            )
        }

        if featureFlags.useRemoteContent && configuredAnonKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append(.missingAnonKey)
        }

        if featureFlags.enableRemoteCampusConfig && !featureFlags.useRemoteContent {
            issues.append(.remoteCampusConfigRequiresRemoteContent)
            featureFlags.enableRemoteCampusConfig = false
        }

        return AppEnvironment(
            name: environmentName,
            apiBaseURL: apiBaseURL,
            anonKey: configuredAnonKey,
            contentVersion: configuredContentVersion,
            featureFlags: featureFlags,
            configurationIssues: issues
        )
    }

    private static func defaultsForEnvironment(_ name: AppEnvironmentName) -> AppEnvironment {
        switch name {
        case .development:
            return .development
        case .staging:
            return .staging
        case .production:
            return .production
        }
    }

    private static func stringValue(for key: String, bundle: Bundle, processInfo: ProcessInfo) -> String? {
        if let processValue = processInfo.environment[key], !processValue.isEmpty {
            return processValue
        }
        guard let infoValue = bundle.object(forInfoDictionaryKey: key) else {
            return nil
        }
        if let stringValue = infoValue as? String {
            return stringValue.isEmpty ? nil : stringValue
        }
        if let boolValue = infoValue as? Bool {
            return boolValue ? "true" : "false"
        }
        if let numberValue = infoValue as? NSNumber {
            return numberValue.stringValue
        }
        return String(describing: infoValue)
    }

    private static func boolValue(for key: String, bundle: Bundle, processInfo: ProcessInfo) -> Bool? {
        guard let rawValue = stringValue(for: key, bundle: bundle, processInfo: processInfo) else {
            return nil
        }

        switch rawValue.lowercased() {
        case "1", "true", "yes", "on":
            return true
        case "0", "false", "no", "off":
            return false
        default:
            return nil
        }
    }
}
