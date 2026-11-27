import Foundation
import SwiftUI
#if canImport(ActivityKit)
import ActivityKit
#endif

/// Things both the app and the widgets need to agree on.
enum LullShared {
    static let appGroup = "group.com.liamwinckel.lull"
    static var defaults: UserDefaults { UserDefaults(suiteName: appGroup) ?? .standard }

    /// The guided sessions (ids match the lamp's sessions in index.html).
    static let sessions: [(id: String, name: String, minutes: Int)] = [
        ("unwind", "Unwind", 8), ("sleep", "Drift to sleep", 15), ("focus", "Focus reset", 5),
        ("sos", "Quick calm", 2), ("morning", "Morning", 6), ("drift", "Underwater", 10),
    ]

    /// The current lava colours, saved by the app so widgets can draw a matching lamp.
    struct Palette: Codable, Equatable {
        var name = "Classic"
        var hot = "#ff6a3d", cool = "#ffb347", liqTop = "#0b0306", liqBot = "#3a0a12"
    }
    static var palette: Palette {
        get { (defaults.data(forKey: "palette")).flatMap { try? JSONDecoder().decode(Palette.self, from: $0) } ?? Palette() }
        set { defaults.set(try? JSONEncoder().encode(newValue), forKey: "palette") }
    }
}

extension Color {
    /// "#rrggbb" -> Color
    init(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespaces); if s.hasPrefix("#") { s.removeFirst() }
        var v: UInt64 = 0; Scanner(string: s).scanHexInt64(&v)
        self.init(red: Double((v >> 16) & 0xff) / 255, green: Double((v >> 8) & 0xff) / 255, blue: Double(v & 0xff) / 255)
    }
}

#if canImport(ActivityKit)
/// The Live Activity shown on the Lock Screen and in the Dynamic Island during a session.
struct SessionActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var endDate: Date
        var hot: String
        var cool: String
    }
    var sessionName: String
}
#endif
