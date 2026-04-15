import Foundation
import os

enum AppLogCategory: String {
    case startup = "Startup"
    case contentSync = "ContentSync"
    case api = "APIClient"
    case auth = "Auth"
    case ar = "AR"
    case checkIn = "CheckIn"
    case model = "ModelController"
}

enum AppLogger {
    static var subsystem: String {
        Bundle.main.bundleIdentifier ?? "HensonDay"
    }

    static func make(_ category: AppLogCategory) -> Logger {
        Logger(subsystem: subsystem, category: category.rawValue)
    }
}