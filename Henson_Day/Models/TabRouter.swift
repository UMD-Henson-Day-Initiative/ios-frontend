import Foundation
import Combine

enum AppTab: Hashable {
    case map
    case home
    case schedule
    case collection
    case profile
    case leaderboard
}

@MainActor
final class TabRouter: ObservableObject {
    @Published var selectedTab: AppTab = .map
    @Published var focusedScheduleEventID: String?
}
