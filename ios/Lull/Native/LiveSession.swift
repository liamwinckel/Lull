import ActivityKit
import Foundation

/// The session timer on the Lock Screen and in the Dynamic Island.
@MainActor
final class LiveSession {
    static let shared = LiveSession()
    private var activity: Activity<SessionActivityAttributes>?
    var palette = LullShared.palette

    func start(name: String, end: Date) {
        endNow()
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let state = SessionActivityAttributes.ContentState(endDate: end, hot: palette.hot, cool: palette.cool)
        activity = try? Activity.request(attributes: SessionActivityAttributes(sessionName: name),
                                         content: .init(state: state, staleDate: end.addingTimeInterval(60)))
    }
    func end() { endNow() }
    private func endNow() {
        guard let a = activity else { return }
        activity = nil
        Task { await a.end(nil, dismissalPolicy: .immediate) }
    }
}
