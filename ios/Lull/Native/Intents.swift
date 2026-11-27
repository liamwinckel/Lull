import AppIntents

/// "Hey Siri, start Unwind in Lull" — and every session shows up in the Shortcuts app.
enum LullSession: String, AppEnum, CaseIterable {
    case unwind, sleep, focus, sos, morning, drift

    static var typeDisplayRepresentation: TypeDisplayRepresentation { "Session" }
    static var caseDisplayRepresentations: [LullSession: DisplayRepresentation] {
        [.unwind: "Unwind", .sleep: "Drift to sleep", .focus: "Focus reset",
         .sos: "Quick calm", .morning: "Morning", .drift: "Underwater"]
    }
}

struct StartSessionIntent: AppIntent {
    static var title: LocalizedStringResource { "Start a Lull session" }
    static var description: IntentDescription { IntentDescription("Opens Lull and begins a guided session.") }
    static var openAppWhenRun: Bool { true }

    @Parameter(title: "Session", default: .unwind)
    var session: LullSession

    @MainActor
    func perform() async throws -> some IntentResult {
        AppState.shared.startSession(session.rawValue)
        return .result()
    }
}

struct LullShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: StartSessionIntent(),
                    phrases: ["Start \(\.$session) in \(.applicationName)",
                              "Start a \(.applicationName) session",
                              "\(.applicationName) \(\.$session)"],
                    shortTitle: "Start session",
                    systemImageName: "drop.fill")
    }
}
