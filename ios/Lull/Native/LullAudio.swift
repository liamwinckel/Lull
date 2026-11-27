import AVFoundation
import os

/// Native sound: the soundscapes, generative music and tones run here (not in the web view),
/// so they keep playing with the screen locked and fade out on the sleep timer.
/// Taps, pops, blubs and the breath sound stay in the lamp.
@MainActor
final class LullAudio {
    static let shared = LullAudio()

    private let engine = AVAudioEngine()
    private var node: AVAudioSourceNode?
    private let synth: Synth
    private var timer: DispatchSourceTimer?
    private var running = false
    var onNote: ((Double) -> Void)?

    private var on = false, music = "off", musicVol: Float = 0.55
    private var nextNote = 2.0
    private var lastPhaseAt = Date.distantPast
    var sleepAt: Date?

    private static let penta: [Float] = [73.42, 82.41, 92.5, 110, 123.47, 146.83, 164.81, 185, 220, 246.94, 293.66, 329.63, 369.99, 440]
    private static let scapeNames = ["drone": "Drone", "underwater": "Underwater", "rain": "Rain", "ocean": "Ocean", "off": "Lull"]

    private init() {
        let sr = AVAudioSession.sharedInstance().sampleRate
        synth = Synth(sampleRate: Float(sr > 0 ? sr : 48000))
        NotificationCenter.default.addObserver(forName: AVAudioSession.interruptionNotification, object: nil, queue: .main) { [weak self] n in
            guard let raw = n.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
                  AVAudioSession.InterruptionType(rawValue: raw) == .ended else { return }
            MainActor.assumeIsolated { self?.restartIfNeeded() }
        }
    }

    func configureSession() {
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [])
    }

    // MARK: settings from the lamp
    func update(on: Bool, volume: Float, ambVol: Float, scape: String, music: String, musicVol: Float, hz: Double, hzVol: Float) {
        self.on = on; self.music = music; self.musicVol = musicVol
        synth.masterT = on ? volume * 0.9 : 0
        synth.ambT = ambVol * 1.4
        synth.setScape(scape)
        synth.musicT = musicVol * 1.5
        synth.hzFreqT = Float(hz)
        synth.hzT = hz > 0 ? hzVol * 1.2 : 0
        NowPlaying.shared.scapeName = Self.scapeNames[scape] ?? "Lull"
        NowPlaying.shared.playing = on && volume > 0.001
        if on { startEngine() } else { stopEngineSoon() }
    }

    func breathPhase(_ ph: Int) {
        lastPhaseAt = Date()
        if ph == 0, on, music == "bowl" { play("bowl", Self.pick(0, 6), 0.8); nextNote = 9 }
    }
    func chime() { if on { play("bowl", Self.penta[5], 0.9) } }

    // MARK: engine
    private func startEngine() {
        if running { return }
        let s = synth
        let fmt = AVAudioFormat(standardFormatWithSampleRate: Double(s.sr), channels: 2)!
        if node == nil {
            let n = Self.makeNode(s, fmt)
            engine.attach(n)
            engine.connect(n, to: engine.mainMixerNode, format: fmt)
            node = n
        }
        do {
            try AVAudioSession.sharedInstance().setActive(true)
            engine.prepare()
            try engine.start()
            running = true
            startTimer()
        } catch { running = false }
    }
    private var stopWork: DispatchWorkItem?
    /// built outside the main actor: this block runs on the real-time audio thread
    nonisolated private static func makeNode(_ s: Synth, _ fmt: AVAudioFormat) -> AVAudioSourceNode {
        AVAudioSourceNode(format: fmt) { _, _, frameCount, abl -> OSStatus in
            let bufs = UnsafeMutableAudioBufferListPointer(abl)
            guard bufs.count >= 2, let l = bufs[0].mData?.assumingMemoryBound(to: Float.self),
                  let r = bufs[1].mData?.assumingMemoryBound(to: Float.self) else { return noErr }
            s.render(Int(frameCount), l, r)
            return noErr
        }
    }
    private func stopEngineSoon() {
        stopWork?.cancel()
        let w = DispatchWorkItem { [weak self] in
            MainActor.assumeIsolated {
                guard let self, !self.on, self.running else { return }
                self.engine.pause(); self.running = false; self.timer?.cancel(); self.timer = nil
            }
        }
        stopWork = w
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5, execute: w)
    }
    private func restartIfNeeded() {
        guard on else { return }
        running = false
        startEngine()
    }

    // MARK: the slow generative player + sleep fade (runs every 0.1 s, also in the background)
    private func startTimer() {
        guard timer == nil else { return }
        let t = DispatchSource.makeTimerSource(queue: .main)
        t.schedule(deadline: .now() + 0.1, repeating: 0.1)
        t.setEventHandler { [weak self] in MainActor.assumeIsolated { self?.tick(0.1) } }
        t.resume(); timer = t
    }
    private func tick(_ dt: Double) {
        if let at = sleepAt, Date() > at {
            synth.sleepT = Float(max(0, 1 - Date().timeIntervalSince(at) / 40))
        } else { synth.sleepT = 1 }
        guard on, music != "off", musicVol > 0.001 else { return }
        nextNote -= dt
        guard nextNote <= 0 else { return }
        let P = Self.penta
        switch music {
        case "bowl":
            if Date().timeIntervalSince(lastPhaseAt) > 15 { play("bowl", Self.pick(0, 7), 1) }
            nextNote = 8 + Double.random(in: 0...7)
        case "piano":
            let i = Int.random(in: 3...10); play("piano", P[i], 1)
            if Double.random(in: 0...1) < 0.35 { after(0.38) { $0.play("piano", P[min(i + 2, 13)], 0.7) } }
            nextNote = 2.4 + Double.random(in: 0...3.6)
        case "harp":
            let i = Int.random(in: 4...9), n = Int.random(in: 2...4)
            for k in 0..<n { after(Double(k) * 0.23) { $0.play("harp", P[min(i + k, 13)], Float(0.8 - Double(k) * 0.12)) } }
            nextNote = 3.5 + Double.random(in: 0...4)
        case "pad":
            play("pad", Self.pick(0, 5), 1)
            nextNote = 8 + Double.random(in: 0...4)
        default: break
        }
    }
    private func after(_ s: Double, _ f: @escaping (LullAudio) -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + s) { [weak self] in MainActor.assumeIsolated { if let self { f(self) } } }
    }
    private static func pick(_ lo: Int, _ hi: Int) -> Float { penta[Int.random(in: lo..<hi)] }

    // one instrument note (mirrors the lamp's web synth), and a glow in the lava
    private func play(_ kind: String, _ f: Float, _ vel: Float) {
        let sr = synth.sr
        switch kind {
        case "bowl":
            let ms: [Float] = [1, 2.76, 5.4, 8.93], amps: [Float] = [0.1, 0.04, 0.018, 0.007]
            synth.add(Voice.partials((0..<4).map { (f * 2 * ms[$0], amps[$0] * vel, 9 - ms[$0] * 0.6) }, attack: 0.02, sr: sr))
            synth.add(Voice.partials((0..<4).map { (f * 2 * ms[$0] * 1.003, amps[$0] * vel * 0.6, max(1, 8 - ms[$0] * 0.6)) }, attack: 0.02, sr: sr))
        case "piano":
            synth.add(Voice.partials([(f * 2, 0.11 * vel, 3.4), (f * 6, 0.11 / 9 * vel, 2.2), (f * 10, 0.11 / 25 * vel, 1.4), (f * 4, 0.025 * vel, 1.4)], attack: 0.006, sr: sr))
        case "harp":
            synth.add(Voice.partials([(f * 2, 0.09 * vel, 2.2), (f * 6, 0.015 * vel, 0.6), (f * 4, 0.02 * vel, 0.9)], attack: 0.003, sr: sr))
        case "pad":
            for (i, m) in [Float(1), 1.5, 2].enumerated() {
                synth.add(Voice.pad(f * m * powf(2, Float(i - 1) * 6 / 1200), peak: 0.03 * vel, sr: sr))
            }
        default: return
        }
        onNote?(Double(kind == "pad" ? 0.5 : 0.8) * Double(vel))
    }
}

/// One sounding note: up to four decaying sine partials, or a slow pad.
struct Voice {
    var freq = SIMD4<Float>(repeating: 0), amp = SIMD4<Float>(repeating: 0), decay = SIMD4<Float>(repeating: 1), phase = SIMD4<Float>(repeating: 0)
    var attack: Float = 1, age: Float = 0, isPad = false, peak: Float = 0

    static func partials(_ p: [(Float, Float, Float)], attack: Float, sr: Float) -> Voice {
        var v = Voice()
        for (i, x) in p.prefix(4).enumerated() {
            v.freq[i] = x.0; v.amp[i] = x.1
            v.decay[i] = expf(logf(1e-4) / (max(x.2, 0.05) * sr))   // like an exponential ramp to silence
        }
        v.attack = max(1, attack * sr)
        return v
    }
    static func pad(_ f: Float, peak: Float, sr: Float) -> Voice {
        var v = Voice(); v.freq[0] = f; v.isPad = true; v.peak = peak; return v
    }
}

/// The sample-by-sample synthesiser. Targets are set from the main thread; render runs on the audio thread.
final class Synth {
    let sr: Float
    // targets
    var masterT: Float = 0, ambT: Float = 1, musicT: Float = 0.8, hzT: Float = 0, hzFreqT: Float = 0, sleepT: Float = 1
    private var scapeT = SIMD4<Float>(1, 0, 0, 0)           // drone, underwater, rain, ocean
    // smoothed values
    private var master: Float = 0, amb: Float = 1, mus: Float = 0.8, hzG: Float = 0, hzF: Float = 0, sleep: Float = 1
    private var scapeG = SIMD4<Float>(0, 0, 0, 0)
    // incoming notes
    private let inbox = OSAllocatedUnfairLock(initialState: [Voice]())
    private var voices: [Voice] = []

    // noise
    private var rng: UInt32 = 0x9E3779B9, brown: Float = 0
    // drone
    private let droneF: [Float] = [55, 82.41, 110.2, 164.8, 220.4], droneA: [Float] = [0.45, 0.3, 0.22, 0.12, 0.05]
    private var dronePh = [Float](repeating: 0, count: 5), droneL = [Float](repeating: 0, count: 5), droneLR: [Float]
    private var droneFilt = Biquad(), droneNoise = Biquad()
    // underwater / rain / ocean
    private var uwF = Biquad(), humPh: Float = 0
    private var rainH = Biquad(), rainL = Biquad(), rainR = Biquad()
    private var ocL = Biquad(), ocH = Biquad()
    // tone
    private var hzPh = SIMD4<Float>(repeating: 0)
    // echo for music
    private var echo: [Float], echoI = 0, echoLP = Biquad()
    private var t: Double = 0, ctl = 0

    init(sampleRate: Float) {
        sr = sampleRate
        droneLR = (0..<5).map { _ in Float.random(in: 0.04...0.13) }
        echo = [Float](repeating: 0, count: Int(sampleRate * 0.37))
        droneNoise.set(.lowpass, 420, 0.707, sr)
        rainH.set(.highpass, 1400, 0.707, sr); rainL.set(.lowpass, 7000, 0.707, sr); rainR.set(.lowpass, 500, 0.707, sr)
        ocH.set(.highpass, 2200, 0.707, sr)
        echoLP.set(.lowpass, 1600, 0.707, sr)
        voices.reserveCapacity(64)
    }

    func setScape(_ id: String) {
        scapeT = SIMD4<Float>(id == "drone" ? 1 : 0, id == "underwater" ? 1 : 0, id == "rain" ? 1 : 0, id == "ocean" ? 1 : 0)
    }
    func add(_ v: Voice) { inbox.withLock { if $0.count < 32 { $0.append(v) } } }

    @inline(__always) private func white() -> Float {
        rng ^= rng << 13; rng ^= rng >> 17; rng ^= rng << 5
        return Float(Int32(bitPattern: rng)) / 2_147_483_648
    }

    func render(_ n: Int, _ L: UnsafeMutablePointer<Float>, _ R: UnsafeMutablePointer<Float>) {
        if let new = inbox.withLockIfAvailable({ st -> [Voice]? in
            if st.isEmpty { return nil }; let x = st; st.removeAll(keepingCapacity: true); return x }) ?? nil {
            for v in new where voices.count < 56 { voices.append(v) }
        }
        let twoPi: Float = 2 * .pi, inv = 1 / sr
        let kFast = 1 - expf(-1 / (0.15 * sr)), kSlow = 1 - expf(-1 / (1.4 * sr)), kMaster = 1 - expf(-1 / (0.5 * sr))
        for i in 0..<n {
            // slowly changing things, every 64 samples
            if ctl == 0 {
                let ts = Float(t)
                droneFilt.set(.lowpass, max(120, 340 + 110 * sinf(twoPi * 0.035 * ts)), 0.8, sr)
                uwF.set(.lowpass, 230 + 70 * sinf(twoPi * 0.05 * ts), 1.2, sr)
                ocL.set(.lowpass, max(150, 650 + 380 * sinf(twoPi * 0.085 * ts)), 0.707, sr)
            }
            ctl = (ctl + 1) & 63
            t += Double(inv)
            let ts = Float(t)

            master += (masterT - master) * kMaster
            sleep += (sleepT - sleep) * kFast
            amb += (ambT - amb) * kFast
            mus += (musicT - mus) * kFast
            scapeG += (scapeT - scapeG) * kSlow

            let w = white()
            brown = (brown + 0.02 * w) / 1.02
            let b = brown * 3.5

            // ---- soundscape
            var sc: Float = 0
            if scapeG[0] > 1e-4 {
                var s: Float = 0
                for k in 0..<5 {
                    dronePh[k] += twoPi * droneF[k] * inv; if dronePh[k] > twoPi { dronePh[k] -= twoPi }
                    droneL[k] += twoPi * droneLR[k] * inv; if droneL[k] > twoPi { droneL[k] -= twoPi }
                    s += sinf(dronePh[k]) * droneA[k] * (1 + 0.5 * sinf(droneL[k]))
                }
                sc += scapeG[0] * 0.5 * (droneFilt.process(s) + 0.35 * droneNoise.process(b))
            }
            if scapeG[1] > 1e-4 {
                humPh += twoPi * 41 * inv; if humPh > twoPi { humPh -= twoPi }
                sc += scapeG[1] * (1.3 * uwF.process(b) + sinf(humPh) * (0.18 + 0.08 * sinf(twoPi * 0.08 * ts)))
            }
            if scapeG[2] > 1e-4 {
                sc += scapeG[2] * (rainL.process(rainH.process(w)) * (0.16 + 0.03 * sinf(twoPi * 0.11 * ts)) + 0.5 * rainR.process(b))
            }
            if scapeG[3] > 1e-4 {
                let swell = sinf(twoPi * 0.085 * ts)
                sc += scapeG[3] * (ocL.process(b) * max(0, 0.55 + 0.45 * swell) + ocH.process(w) * max(0, 0.04 + 0.035 * swell))
            }
            sc *= amb

            // ---- steady tone: two voices a hair apart, fading through silence when the pitch changes
            let hzTarget: Float = (hzF == hzFreqT) ? hzT : 0
            hzG += (hzTarget - hzG) * kFast * 0.3
            if hzG < 1e-4 && hzF != hzFreqT { hzF = hzFreqT; hzPh = .zero }
            var tone: Float = 0
            if hzG > 1e-4 && hzF > 0 {
                let fr = SIMD4<Float>(hzF - 0.9, hzF + 0.9, 2 * hzF - 1.8, 2 * hzF + 1.8)
                hzPh += fr * (twoPi * inv)
                for k in 0..<4 where hzPh[k] > twoPi { hzPh[k] -= twoPi }
                tone = (0.06 * (sinf(hzPh[0]) + sinf(hzPh[1])) + 0.012 * (sinf(hzPh[2]) + sinf(hzPh[3]))) * hzG
            }

            // ---- music voices
            var m: Float = 0
            var j = 0
            while j < voices.count {
                var v = voices[j]
                var out: Float = 0, alive = true
                if v.isPad {
                    let A = 4 * sr, D = 7 * sr
                    let e: Float = v.age < A ? v.age / A : max(0, 1 - (v.age - A) / D)
                    v.phase[0] += twoPi * v.freq[0] * inv; if v.phase[0] > twoPi { v.phase[0] -= twoPi }
                    var s: Float = 0
                    for h in 1...6 { s += sinf(v.phase[0] * Float(h)) / powf(Float(h), 1.6) }
                    out = s * v.peak * e
                    alive = v.age < A + D
                } else {
                    let a = min(1, v.age / v.attack)
                    v.phase += v.freq * (twoPi * inv)
                    for k in 0..<4 where v.phase[k] > twoPi { v.phase[k] -= twoPi }
                    out = (v.amp[0] * sinf(v.phase[0]) + v.amp[1] * sinf(v.phase[1]) + v.amp[2] * sinf(v.phase[2]) + v.amp[3] * sinf(v.phase[3])) * a
                    if v.age >= v.attack { v.amp *= v.decay }
                    alive = v.amp.max() > 1e-5
                }
                v.age += 1
                m += out
                if alive { voices[j] = v; j += 1 } else { voices.swapAt(j, voices.count - 1); voices.removeLast() }
            }
            m *= mus
            // a soft echo on the music
            let d = echo[echoI]
            let dl = echoLP.process(d)
            echo[echoI] = m * 0.55 + dl * 0.42
            echoI += 1; if echoI >= echo.count { echoI = 0 }
            m += dl

            let x = tanhf((sc + tone + m) * master * sleep)
            L[i] = x; R[i] = x
        }
    }
}

/// Standard RBJ biquad filter.
struct Biquad {
    enum Kind { case lowpass, highpass }
    var b0: Float = 1, b1: Float = 0, b2: Float = 0, a1: Float = 0, a2: Float = 0, z1: Float = 0, z2: Float = 0
    mutating func set(_ k: Kind, _ f: Float, _ q: Float, _ sr: Float) {
        let w = 2 * Float.pi * min(f, sr * 0.45) / sr, c = cosf(w), al = sinf(w) / (2 * q), a0 = 1 + al
        switch k {
        case .lowpass: b0 = (1 - c) / 2 / a0; b1 = (1 - c) / a0; b2 = b0
        case .highpass: b0 = (1 + c) / 2 / a0; b1 = -(1 + c) / a0; b2 = b0
        }
        a1 = -2 * c / a0; a2 = (1 - al) / a0
    }
    @inline(__always) mutating func process(_ x: Float) -> Float {
        let y = b0 * x + z1
        z1 = b1 * x - a1 * y + z2
        z2 = b2 * x - a2 * y
        return y
    }
}
