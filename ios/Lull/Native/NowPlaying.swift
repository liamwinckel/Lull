import MediaPlayer

/// Shows Lull on the Lock Screen while sound plays, with play/pause.
@MainActor
final class NowPlaying {
    static let shared = NowPlaying()
    var onToggle: ((Bool) -> Void)?
    var session: String? { didSet { refresh() } }
    var playing = false { didSet { if playing != oldValue { refresh() } } }
    var scapeName = "Drone" { didSet { if scapeName != oldValue { refresh() } } }

    func setUpRemoteCommands() {
        let rc = MPRemoteCommandCenter.shared()
        rc.playCommand.addTarget { [weak self] _ in MainActor.assumeIsolated { self?.onToggle?(true) }; return .success }
        rc.pauseCommand.addTarget { [weak self] _ in MainActor.assumeIsolated { self?.onToggle?(false) }; return .success }
        rc.togglePlayPauseCommand.addTarget { [weak self] _ in
            MainActor.assumeIsolated { if let s = self { s.onToggle?(!s.playing) } }; return .success
        }
    }
    private func refresh() {
        let info: [String: Any] = [
            MPMediaItemPropertyTitle: session ?? scapeName,
            MPMediaItemPropertyArtist: "Lull",
            MPNowPlayingInfoPropertyIsLiveStream: true,
            MPNowPlayingInfoPropertyPlaybackRate: playing ? 1.0 : 0.0,
        ]
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
        MPNowPlayingInfoCenter.default().playbackState = playing ? .playing : .paused
    }
}
