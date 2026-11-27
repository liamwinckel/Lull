import SwiftUI
import UserNotifications

@main
struct LullApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onOpenURL { url in AppState.shared.handle(url: url) }
        }
        .onChange(of: scenePhase) { _, phase in
            // keep the screen awake while the lamp is showing, like a real lamp
            UIApplication.shared.isIdleTimerDisabled = (phase == .active)
            if phase == .active { WidgetReloader.reloadSoon() }
        }
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        LullAudio.shared.configureSession()
        NowPlaying.shared.setUpRemoteCommands()
        return true
    }
    // tapping the bedtime reminder opens straight into the sleep session
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        if let id = response.notification.request.content.userInfo["session"] as? String {
            await MainActor.run { AppState.shared.startSession(id) }
        }
    }
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}

/// App-wide state: the web lamp, and anything waiting to be sent to it.
@MainActor
final class AppState: ObservableObject {
    static let shared = AppState()
    weak var bridge: LampBridge?
    private var pendingSession: String?
    var lampReady = false { didSet { flush() } }

    func startSession(_ id: String) {
        pendingSession = id
        flush()
    }
    func handle(url: URL) {
        // lull://session/<id>
        guard url.scheme == "lull" else { return }
        if url.host == "session", let id = url.pathComponents.dropFirst().first { startSession(id) }
    }
    private func flush() {
        guard lampReady, let id = pendingSession, let bridge else { return }
        pendingSession = nil
        bridge.run("window.__lullStartSession && window.__lullStartSession('\(id)')")
    }
}
