import CoreMotion

/// Shake & tilt. Native motion needs no permission prompt, so it simply works when switched on.
@MainActor
final class Motion {
    static let shared = Motion()
    private let manager = CMMotionManager()
    var onSample: ((Double, Double, Double) -> Void)?

    func start() {
        guard manager.isDeviceMotionAvailable, !manager.isDeviceMotionActive else { return }
        manager.deviceMotionUpdateInterval = 1.0 / 30.0
        manager.startDeviceMotionUpdates(to: .main) { [weak self] data, _ in
            guard let d = data else { return }
            // same units and directions the lamp already understands (Safari's accelerationIncludingGravity, m/s²)
            let g = 9.81
            let x = (d.gravity.x + d.userAcceleration.x) * g
            let y = (d.gravity.y + d.userAcceleration.y) * g
            let z = (d.gravity.z + d.userAcceleration.z) * g
            MainActor.assumeIsolated { self?.onSample?(x, y, z) }
        }
    }
    func stop() { manager.stopDeviceMotionUpdates() }
}
