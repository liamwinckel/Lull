import SwiftUI
import WebKit
import WidgetKit

/// The lamp itself: the same lava engine as the web version (GPU-rendered via WebGL),
/// running inside the app with native audio, haptics, motion, Health, widgets and Live Activities around it.
struct LampWebView: UIViewRepresentable {
    func makeCoordinator() -> LampBridge { LampBridge() }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        config.userContentController.add(WeakHandler(context.coordinator), name: "lull")
        config.websiteDataStore = .default()   // keeps presets, favourites and settings between launches

        let web = WKWebView(frame: .zero, configuration: config)
        web.isOpaque = false
        web.backgroundColor = .black
        web.scrollView.backgroundColor = .black
        web.scrollView.isScrollEnabled = false
        web.scrollView.bounces = false
        web.scrollView.contentInsetAdjustmentBehavior = .never
        web.allowsLinkPreview = false
        #if DEBUG
        if #available(iOS 16.4, *) { web.isInspectable = true }   // Safari > Develop can inspect the lamp
        #endif
        context.coordinator.webView = web
        AppState.shared.bridge = context.coordinator

        if let url = Bundle.main.url(forResource: "index", withExtension: "html", subdirectory: "Web") {
            web.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        }
        return web
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}
}

/// WKUserContentController holds its handler strongly; this breaks the cycle.
final class WeakHandler: NSObject, WKScriptMessageHandler {
    weak var target: WKScriptMessageHandler?
    init(_ target: WKScriptMessageHandler) { self.target = target }
    func userContentController(_ c: WKUserContentController, didReceive message: WKScriptMessage) {
        target?.userContentController(c, didReceive: message)
    }
}

/// Receives messages from the lamp (see `nat(...)` in index.html) and hands them to the native features.
@MainActor
final class LampBridge: NSObject, WKScriptMessageHandler {
    weak var webView: WKWebView?
    private var sessionStart: Date?

    func run(_ js: String) {
        webView?.evaluateJavaScript(js, completionHandler: nil)
    }

    nonisolated func userContentController(_ c: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let body = message.body as? [String: Any], let type = body["type"] as? String else { return }
        Task { @MainActor in self.handle(type, body) }
    }

    private func num(_ v: Any?) -> Double { (v as? NSNumber)?.doubleValue ?? 0 }

    private func handle(_ type: String, _ b: [String: Any]) {
        switch type {
        case "ready":
            AppState.shared.lampReady = true
            Motion.shared.onSample = { [weak self] x, y, z in
                self?.run(String(format: "window.__lullMotion && window.__lullMotion(%.3f,%.3f,%.3f)", x, y, z))
            }
            LullAudio.shared.onNote = { [weak self] v in
                self?.run(String(format: "window.__lullNote && window.__lullNote(%.2f)", v))
            }
            NowPlaying.shared.onToggle = { [weak self] on in self?.run("window.__lullSetSound && window.__lullSetSound(\(on))") }

        case "haptic":
            Haptics.shared.play(b["k"] as? String ?? "light")

        case "motion":
            (b["on"] as? Bool ?? false) ? Motion.shared.start() : Motion.shared.stop()

        case "audio":
            LullAudio.shared.update(
                on: b["on"] as? Bool ?? true, volume: Float(num(b["volume"])), ambVol: Float(num(b["ambVol"])),
                scape: b["scape"] as? String ?? "drone", music: b["music"] as? String ?? "off",
                musicVol: Float(num(b["musicVol"])), hz: num(b["hz"]), hzVol: Float(num(b["hzVol"])))

        case "phase":
            LullAudio.shared.breathPhase(Int(num(b["ph"])))

        case "chime":
            LullAudio.shared.chime()

        case "sleep":
            let at = num(b["at"])
            LullAudio.shared.sleepAt = at > 0 ? Date(timeIntervalSince1970: at / 1000) : nil

        case "session":
            let name = b["name"] as? String ?? "Session"
            if (b["state"] as? String) == "start" {
                sessionStart = Date()
                let end = Date().addingTimeInterval(num(b["minutes"]) * 60)
                LiveSession.shared.start(name: name, end: end)
                NowPlaying.shared.session = name
                Health.shared.requestAccessIfNeeded()
            } else {
                LiveSession.shared.end()
                NowPlaying.shared.session = nil
                if let s = sessionStart, Date().timeIntervalSince(s) >= 30 { Health.shared.logMindful(from: s, to: Date()) }
                sessionStart = nil
            }

        case "reminder":
            Reminders.set(on: b["on"] as? Bool ?? false, hour: Int(num(b["hour"])), minute: Int(num(b["minute"])))

        case "theme":
            let p = LullShared.Palette(name: b["name"] as? String ?? "", hot: b["hot"] as? String ?? "#ff6a3d",
                                       cool: b["cool"] as? String ?? "#ffb347", liqTop: b["liqTop"] as? String ?? "#0b0306",
                                       liqBot: b["liqBot"] as? String ?? "#3a0a12")
            if p != LullShared.palette { LullShared.palette = p; WidgetReloader.reloadSoon() }
            LiveSession.shared.palette = p

        default: break
        }
    }
}

/// Widgets refresh at most every few seconds (theme changes can come quickly while browsing).
enum WidgetReloader {
    private static var pending = false
    static func reloadSoon() {
        guard !pending else { return }
        pending = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { pending = false; WidgetCenter.shared.reloadAllTimelines() }
    }
}
