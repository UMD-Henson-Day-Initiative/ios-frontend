import Foundation
import Combine

enum AppTab: Hashable {
    case home
    case schedule
    case map
    case leaderboard
    case profile
}

@MainActor
final class TabRouter: ObservableObject {
    @Published var selectedTab: AppTab = .home
    /// Set by ScheduleScreen when an event row is tapped; MapScreen observes
    /// this to jump to and open that event's pin, then clears it back to nil.
    @Published var focusedEventID: String?
}
