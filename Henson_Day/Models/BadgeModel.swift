//
//  BadgeModel 2.swift
//  Henson_Day
//
//  Created by Jake Frischmann on 2/27/26.
//

/// Pretty straight forward
struct BadgeModel: Identifiable, Codable {
    let id: String
    let name: String
    let description: String
    let progress: Int
    let total: Int
    var unlocked: Bool
}
