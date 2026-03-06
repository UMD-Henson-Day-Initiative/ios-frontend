//
//  EventType.swift
//  Henson_Day
//
//  Created by Jake Frischmann on 2/27/26.
//


enum EventType: String, Codable {
    case common
    case rare
    case homebase
}

struct Event: Identifiable, Codable {
    let id: String
    let name: String
    let day: Int
    let time: String
    let location: String
    let description: String
    let type: EventType
    let collectibleId: String?
}
