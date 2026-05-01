import Foundation
#if canImport(Supabase)
import Supabase
#endif

#if canImport(Supabase)
typealias SupabaseAppClient = SupabaseClient
#else
struct SupabaseAppClient {}
#endif

enum SupabaseClientConfigurationError: LocalizedError {
  case missingURL
  case invalidURL(String)
  case missingPublishableKey

  var errorDescription: String? {
    switch self {
    case .missingURL:
      return "Missing SUPABASE_URL. Add it to your app configuration."
    case .invalidURL(let value):
      return "SUPABASE_URL is invalid: \(value)"
    case .missingPublishableKey:
      return "Missing SUPABASE_PUBLISHABLE_KEY. Add it to your app configuration."
    }
  }
}

private enum SupabaseConfiguration {
  static let urlKey = "SUPABASE_URL"
  static let publishableKey = "SUPABASE_PUBLISHABLE_KEY"

  static func value(for key: String, bundle: Bundle = .main, processInfo: ProcessInfo = .processInfo) -> String? {
    if let envValue = processInfo.environment[key], !envValue.isEmpty {
      return envValue
    }

    guard let raw = bundle.object(forInfoDictionaryKey: key) as? String else {
      return nil
    }

    let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? nil : trimmed
  }

  static func clientResult(bundle: Bundle = .main, processInfo: ProcessInfo = .processInfo) -> Result<SupabaseAppClient, Error> {
#if canImport(Supabase)
    guard let urlString = value(for: urlKey, bundle: bundle, processInfo: processInfo) else {
      return .failure(SupabaseClientConfigurationError.missingURL)
    }

    guard let url = URL(string: urlString), url.scheme != nil else {
      return .failure(SupabaseClientConfigurationError.invalidURL(urlString))
    }

    guard let key = value(for: publishableKey, bundle: bundle, processInfo: processInfo) else {
      return .failure(SupabaseClientConfigurationError.missingPublishableKey)
    }

    return .success(SupabaseClient(supabaseURL: url, supabaseKey: key))
#else
    return .failure(SupabaseClientConfigurationError.missingPublishableKey)
#endif
  }
}

enum SupabaseClientProvider {
  static let configuredClient: Result<SupabaseAppClient, Error> = SupabaseConfiguration.clientResult()

  static var client: SupabaseAppClient? {
    try? configuredClient.get()
  }

  static var configurationErrorDescription: String? {
#if canImport(Supabase)
    switch configuredClient {
    case .success:
      return nil
    case .failure(let error):
      return (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
    }
#else
    return "Supabase SDK is not installed. Add https://github.com/supabase/supabase-swift to the project packages."
#endif
  }
}

let supabase: SupabaseAppClient? = SupabaseClientProvider.client

