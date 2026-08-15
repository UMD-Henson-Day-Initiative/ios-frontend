import Foundation

/// The signed-in user's profile, as returned by `GET /me`.
struct Profile: Codable, Equatable {
    let id: String
    let email: String
    let firstName: String
    let lastName: String
    let totalPoints: Int
    let eventsAttended: Int

    enum CodingKeys: String, CodingKey {
        case id, email
        case firstName = "first_name"
        case lastName = "last_name"
        case totalPoints = "total_points"
        case eventsAttended = "events_attended"
    }

    var fullName: String {
        [firstName, lastName].filter { !$0.isEmpty }.joined(separator: " ")
    }
}

/// A scheduled event, as returned by `GET /events` and `GET /events/<id>`.
struct EventItem: Codable, Equatable, Identifiable {
    let id: String
    let title: String
    let description: String
    let locationName: String
    let latitude: Double
    let longitude: Double
    let startTime: Date
    let endTime: Date?
    let points: Int
    var collected: Bool

    enum CodingKeys: String, CodingKey {
        case id, title, description, latitude, longitude, points, collected
        case locationName = "location_name"
        case startTime = "start_time"
        case endTime = "end_time"
    }
}

/// One row of `GET /leaderboard`.
struct LeaderboardEntry: Codable, Equatable, Identifiable {
    let rank: Int
    let userID: String
    let firstName: String
    let lastName: String
    let totalPoints: Int
    let eventsAttended: Int

    enum CodingKeys: String, CodingKey {
        case rank
        case userID = "user_id"
        case firstName = "first_name"
        case lastName = "last_name"
        case totalPoints = "total_points"
        case eventsAttended = "events_attended"
    }

    var id: String { userID }

    var fullName: String {
        [firstName, lastName].filter { !$0.isEmpty }.joined(separator: " ")
    }
}

/// Response body of `POST /events/<id>/collect` on success.
struct CollectResult: Codable, Equatable {
    let success: Bool
    let pointsAwarded: Int
    let distanceMeters: Double
    let totalPoints: Int
    let eventsAttended: Int

    enum CodingKeys: String, CodingKey {
        case success
        case pointsAwarded = "points_awarded"
        case distanceMeters = "distance_meters"
        case totalPoints = "total_points"
        case eventsAttended = "events_attended"
    }
}

/// Error body the backend returns for non-2xx responses, e.g. `{"error": "too far away", "distance_meters": 512.3}`.
struct BackendErrorPayload: Codable {
    let error: String
    let distanceMeters: Double?

    enum CodingKeys: String, CodingKey {
        case error
        case distanceMeters = "distance_meters"
    }
}

enum BackendError: LocalizedError {
    case notAuthenticated
    case wrongDomain(message: String)
    case tooFarAway(distanceMeters: Double)
    case alreadyCollected
    case server(message: String, statusCode: Int)
    case network(Error)
    case decoding(Error)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "You're not signed in."
        case .wrongDomain(let message):
            return message
        case .tooFarAway(let distance):
            return "You're too far away (\(Int(distance.rounded()))m). Get within 0.1 miles to collect."
        case .alreadyCollected:
            return "You already collected this event's coin."
        case .server(let message, _):
            return message
        case .network:
            return "Couldn't reach the server. Check your connection and try again."
        case .decoding:
            return "The server sent back something unexpected."
        }
    }
}
