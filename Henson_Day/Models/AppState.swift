//
//  AppState.swift
//  Henson_Day
//
//  Created by Jake Frischmann on 2/27/26.
//

import Foundation
import Combine


// AppState.swift (add / refine)

@MainActor
final class AppState: ObservableObject {
    
    @Published var currentUser: User?
    @Published var events: [Event] = []
    @Published var collectibles: [Collectible] = []
    @Published var badges: [BadgeModel] = []
    @Published var leaderboardUsers: [LeaderboardUser] = []

    
    //cntr+CMD+space for emojis
    
    private func seedMock() {
        currentUser = User(
            id: "u1",
            name: "You",
            avatarEmoji: "🐢",
            score: 420,
            eventsVisited: 9
        )

        collectibles = [
            Collectible(
                id: "c1",
                name: "Quantum Smth",
                emoji: "⚛️",
                colorHex: "#FFD200",
                rarity: .rare,
                points: 150,
                location: "IRB Atrium",
                flavorText: "A curious critter who loves quantum talks.",
                obtained: true
            ),
            Collectible(
                id: "c2",
                name: "Mall Muppet",
                emoji: "🧸",
                colorHex: "#E21833",
                rarity: .common,
                points: 40,
                location: "McKeldin Mall",
                flavorText: "Muppet smthing",
                obtained: false
            )
        ]

        events = [
            Event(
                id: "e1",
                name: "Quantum Conference: Opening Keynote",
                day: 1,
                time: "3:00–4:30 PM",
                location: "IRB Lecture Hall",
                description: "Kick off Henson Week with a deep dive into quantum innovation.",
                type: .homebase,
                collectibleId: "c1"
            ),
            Event(
                id: "e2",
                name: "Live Music",
                day: 1,
                time: "5:00–6:30 PM",
                location: "Clark Hall",
                description: "Student teams demo drones, gliders, and wild flight prototypes.",
                type: .rare,
                collectibleId: "c2"
            )
        ]

        badges = [
            BadgeModel(
                id: "b1",
                name: "Racer Badge",
                description: "Attend 3 events in a single day.",
                progress: 2,
                total: 3,
                unlocked: false
            ),
            BadgeModel(
                id: "b2",
                name: "Explorer Badge",
                description: "Visit 10 different locations on campus.",
                progress: 10,
                total: 10,
                unlocked: true
            )
        ]

        leaderboardUsers = [
            LeaderboardUser(
                id: "u2",
                name: "Alex",
                avatarEmoji: "🦊",
                score: 610,
                eventsVisited: 11,
                isCurrentUser: false
            ),
            LeaderboardUser(
                id: "u3",
                name: "Sam",
                avatarEmoji: "🐼",
                score: 520,
                eventsVisited: 8,
                isCurrentUser: false
            ),
            LeaderboardUser(
                id: "u1",
                name: "You",
                avatarEmoji: "🐢",
                score: 420,
                eventsVisited: 9,
                isCurrentUser: true
            )
        ]
    }
    
    init() {
        seedMock()
    }

    func markCollectibleObtained(id: String) {
        guard let idx = collectibles.firstIndex(where: { $0.id == id }) else { return }
        collectibles[idx].obtained = true
        // TODO: update score, badges, backend
    }
}

