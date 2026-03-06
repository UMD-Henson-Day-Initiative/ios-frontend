//
//  User.swift
//  Henson_Day
//
//  Created by Jake Frischmann on 2/27/26.
//


struct User: Identifiable, Codable {
    let id: String
    var name: String
    var avatarEmoji: String
    var score: Int
    var eventsVisited: Int
}