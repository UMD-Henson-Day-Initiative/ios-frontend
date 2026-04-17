import Foundation
import Combine

/// The five primary tabs in the app's root navigation.
enum AppTab: Hashable {
    case map
    case home
    case schedule
    case collection
    case profile
    case leaderboard
}

/// Manages cross-tab navigation state. Views set `selectedTab` to switch tabs
/// programmatically (e.g., from a map pin to the schedule). `focusedScheduleEventID`
/// enables deep-linking: set it before switching to `.schedule` and ScheduleScreen
/// will auto-scroll to that event.
@MainActor
final class TabRouter: ObservableObject {
    @Published var selectedTab: AppTab = .map
    /// When set, ScheduleScreen scrolls to and highlights the matching event.
    @Published var focusedScheduleEventID: String?
}
