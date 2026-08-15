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
}
