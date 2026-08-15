import Foundation
import Combine
import CoreLocation

/// Single source of truth for backend-fetched app state: the signed-in user's
/// profile, the event schedule, and the leaderboard. Replaces the old
/// SwiftData-backed ModelController — there is no local persistence layer
/// anymore, everything comes from the Flask backend on demand.
@MainActor
final class AppSession: ObservableObject {
    @Published private(set) var profile: Profile?
    @Published private(set) var events: [EventItem] = []
    @Published private(set) var leaderboard: [LeaderboardEntry] = []
    @Published var errorMessage: String?
    /// Set when the backend rejects the signed-in Google account for not
    /// being a UMD email — the caller (HensonDayApp) should sign out in
    /// response, since Supabase itself doesn't restrict by domain.
    @Published private(set) var wrongDomainDetected = false
    @Published private(set) var isLoadingProfile = false
    @Published private(set) var isLoadingEvents = false
    @Published private(set) var isLoadingLeaderboard = false

    private let api: BackendAPI

    init(authManager: AuthManager) {
        self.api = BackendAPI(authManager: authManager)
    }

    func bootstrap() async {
        async let profileTask: Void = loadProfile()
        async let eventsTask: Void = loadEvents()
        async let leaderboardTask: Void = loadLeaderboard()
        _ = await (profileTask, eventsTask, leaderboardTask)
    }

    func loadProfile() async {
        isLoadingProfile = true
        defer { isLoadingProfile = false }
        do {
            profile = try await api.fetchMe()
        } catch BackendError.wrongDomain(let message) {
            errorMessage = message
            wrongDomainDetected = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func loadEvents() async {
        isLoadingEvents = true
        defer { isLoadingEvents = false }
        do {
            events = try await api.fetchEvents().sorted { $0.startTime < $1.startTime }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func loadLeaderboard() async {
        isLoadingLeaderboard = true
        defer { isLoadingLeaderboard = false }
        do {
            leaderboard = try await api.fetchLeaderboard()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Collects the given event's coin. Throws (via `errorMessage`) if the
    /// caller is too far away or already collected it — the backend is the
    /// source of truth for both checks, this just relays the result.
    @discardableResult
    func collectCoin(for event: EventItem, at coordinate: CLLocationCoordinate2D) async -> CollectResult? {
        do {
            let result = try await api.collectCoin(eventID: event.id, lat: coordinate.latitude, lng: coordinate.longitude)

            if let index = events.firstIndex(where: { $0.id == event.id }) {
                events[index].collected = true
            }
            if let profile {
                self.profile = Profile(
                    id: profile.id,
                    email: profile.email,
                    firstName: profile.firstName,
                    lastName: profile.lastName,
                    totalPoints: result.totalPoints,
                    eventsAttended: result.eventsAttended
                )
            }
            return result
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    /// Clears cached state on sign-out. Nothing here is sensitive at rest
    /// (no local persistence), but stale data shouldn't linger past a sign-out.
    func reset() {
        profile = nil
        events = []
        leaderboard = []
        errorMessage = nil
        wrongDomainDetected = false
    }
}
