// AppEnvironment.swift
//
// Backend configuration. Hardcoded rather than read from Info.plist —
// Xcode's INFOPLIST_KEY_* build-setting synthesis does not actually inject
// arbitrary custom keys into the generated Info.plist (confirmed by
// inspecting a built app's actual Info.plist — none of the custom HENSON_*
// keys were present despite being set correctly in project.pbxproj). None
// of these values are secrets (the Supabase key here is the publishable/anon
// key, and the Google client ID is meant to be embedded in app code), so
// hardcoding them is both simpler and actually reliable.
//
// If your Mac's LAN IP changes, update `apiBaseURL` below and rebuild —
// physical-device testing needs your Mac's IP, not "localhost" (the device
// would otherwise look for the backend on itself).

import Foundation

struct AppEnvironment {
    let supabaseURL: URL
    let supabaseAnonKey: String
    let googleIOSClientID: String
    let apiBaseURL: URL

    static let current = AppEnvironment(
        supabaseURL: URL(string: "https://ysxejgyoitphtavtwcdd.supabase.co")!,
        supabaseAnonKey: "sb_publishable_RUEsOvbun6NnCNKqFHYGog_zd4uHrUd",
        googleIOSClientID: "8477921433-v52u5ojulmgk7dug9074f0babdcmev96.apps.googleusercontent.com",
        apiBaseURL: URL(string: "http://192.168.86.25:5000")!
    )
}
