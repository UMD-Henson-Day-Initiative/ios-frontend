import Foundation

struct UserProfileSnapshot {
    let displayName: String
    let totalPoints: Int
    let collectedCount: Int
    let rank: Int
}

enum UserDatabase {
    static func profileSnapshot(from modelController: ModelController) -> UserProfileSnapshot {
        guard let currentUser = modelController.currentUser else {
            return UserProfileSnapshot(displayName: "Player", totalPoints: 0, collectedCount: 0, rank: 0)
        }

        let leaderboard = modelController.leaderboardUsers
        let rank = (leaderboard.firstIndex(where: { $0.id == currentUser.id }) ?? -1) + 1

        return UserProfileSnapshot(
            displayName: currentUser.displayName,
            totalPoints: currentUser.totalPoints,
            collectedCount: currentUser.collectedCount,
            rank: rank
        )
    }

    static func collectedItems(from modelController: ModelController) -> [CollectedItemEntity] {
        modelController.collectionItemsForCurrentUser()
    }
}
