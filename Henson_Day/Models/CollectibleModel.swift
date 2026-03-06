//
//  CollectibleRarity.swift
//  Henson_Day
//
//  Created by Jake Frischmann on 2/27/26.
//


enum CollectibleRarity: String, Codable {
    case common, rare, legendary
}

struct Collectible: Identifiable, Codable {
    let id: String
    let name: String
    let emoji: String
    let colorHex: String
    let rarity: CollectibleRarity
    let points: Int
    let location: String
    let flavorText: String
    var obtained: Bool
}