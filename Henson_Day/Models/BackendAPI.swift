import Foundation

/// Thin REST client for the Flask backend. Every call attaches the current
/// Supabase session's access token as a Bearer header — see `backend/README.md`
/// (henson-backend) for the exact endpoint contracts this mirrors.
@MainActor
final class BackendAPI {
    private let baseURL: URL
    private let authManager: AuthManager
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    init(environment: AppEnvironment = .current, authManager: AuthManager) {
        self.baseURL = environment.apiBaseURL
        self.authManager = authManager

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let string = try container.decode(String.self)

            let withFractional = ISO8601DateFormatter()
            withFractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = withFractional.date(from: string) { return date }

            let standard = ISO8601DateFormatter()
            standard.formatOptions = [.withInternetDateTime]
            if let date = standard.date(from: string) { return date }

            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Expected ISO8601 date, got \(string)"
            )
        }
        self.decoder = decoder
        self.encoder = JSONEncoder()
    }

    func fetchMe() async throws -> Profile {
        try await get(baseURL.appendingPathComponent("me"))
    }

    func fetchEvents(onDay date: Date? = nil) async throws -> [EventItem] {
        var components = URLComponents(url: baseURL.appendingPathComponent("events"), resolvingAgainstBaseURL: false)!
        if let date {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            formatter.timeZone = .current
            components.queryItems = [URLQueryItem(name: "date", value: formatter.string(from: date))]
        }
        return try await get(components.url ?? baseURL.appendingPathComponent("events"))
    }

    func fetchLeaderboard() async throws -> [LeaderboardEntry] {
        try await get(baseURL.appendingPathComponent("leaderboard"))
    }

    func collectCoin(eventID: String, lat: Double, lng: Double) async throws -> CollectResult {
        let url = baseURL.appendingPathComponent("events/\(eventID)/collect")
        let body = try encoder.encode(["lat": lat, "lng": lng])
        return try await send(url: url, method: "POST", body: body)
    }

    // MARK: - Core request plumbing

    private func get<T: Decodable>(_ url: URL) async throws -> T {
        try await send(url: url, method: "GET", body: nil)
    }

    private func send<T: Decodable>(url: URL, method: String, body: Data?) async throws -> T {
        guard let token = authManager.accessToken else {
            throw BackendError.notAuthenticated
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        if let body {
            request.httpBody = body
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw BackendError.network(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw BackendError.network(URLError(.badServerResponse))
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let payload = try? decoder.decode(BackendErrorPayload.self, from: data)
            if httpResponse.statusCode == 403, let distance = payload?.distanceMeters {
                throw BackendError.tooFarAway(distanceMeters: distance)
            }
            if httpResponse.statusCode == 403 {
                // No distance_meters on the payload means this 403 came from the
                // UMD-email domain check, not the collect-radius check.
                throw BackendError.wrongDomain(message: payload?.error ?? "This app is only available to UMD accounts.")
            }
            if httpResponse.statusCode == 409 {
                throw BackendError.alreadyCollected
            }
            throw BackendError.server(message: payload?.error ?? "Something went wrong.", statusCode: httpResponse.statusCode)
        }

        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw BackendError.decoding(error)
        }
    }
}
