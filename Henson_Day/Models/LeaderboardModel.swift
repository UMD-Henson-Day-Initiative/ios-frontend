//
//  LeaderboardUser.swift
//  Henson_Day
//
//  Created by Jake Frischmann on 2/27/26.
//


struct LeaderboardUser: Identifiable, Codable {
    let id: String
    let name: String
    let avatarEmoji: String
    let score: Int
    let eventsVisited: Int
    let isCurrentUser: Bool
}
