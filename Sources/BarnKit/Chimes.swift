import AppKit

/// barn's optional little noises and trackpad taps, both off until turned on in settings.
///
/// The sounds are synthesized once at launch (a few hundred milliseconds of sine waves each,
/// rendered to in-memory WAVs), so there are no audio files to ship or license.
/// Haptics only reach you while a finger is resting on a Force Touch trackpad; otherwise
/// macOS drops them silently.
@MainActor
final class Chimes {
    static let shared = Chimes()

    enum Cue: CaseIterable {
        /// A bubbly rising bloop: a new agent showed up.
        case arrive
        /// The same bloop, falling: an agent exited.
        case leave
        /// A two-note doorbell: an agent needs you.
        case needsYou
        /// A marimba arpeggio: an agent finished its turn.
        case ready
        /// A quick swoop: you jumped to an agent's terminal.
        case jump
    }

    private lazy var sounds: [Cue: NSSound] = Dictionary(uniqueKeysWithValues: Cue.allCases.compactMap { cue in
        NSSound(data: Synth.wav(Self.score(cue))).map { (cue, $0) }
    })

    /// Plays a cue if the user has it turned on.
    func play(_ cue: Cue) {
        let settings = Settings.shared
        if settings.haptics { tap(for: cue) }
        if settings.soundsOn, settings.soundEnabled(for: cue) { sound(cue) }
    }

    /// Plays a cue regardless of settings (the settings pane's preview buttons).
    func preview(_ cue: Cue) {
        sound(cue)
        tap(for: cue)
    }

    /// A light trackpad tick as the switcher's selection moves under the pointer.
    func tick() {
        guard Settings.shared.haptics else { return }
        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
    }

    /// Whether `play` will make a noise for this agent state, so notifications can skip their own.
    func coversSound(for state: AgentState) -> Bool {
        let settings = Settings.shared
        switch state {
        case .waiting: return settings.soundsOn && settings.soundWaiting
        case .ready: return settings.soundsOn && settings.soundReady
        default: return false
        }
    }

    private func sound(_ cue: Cue) {
        guard let sound = sounds[cue] else { return }
        sound.stop() // a burst of the same cue restarts it instead of piling up
        sound.volume = Float(Settings.shared.soundVolume)
        sound.play()
    }

    private func tap(for cue: Cue) {
        let performer = NSHapticFeedbackManager.defaultPerformer
        switch cue {
        case .needsYou:
            performer.perform(.levelChange, performanceTime: .now)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.14) {
                performer.perform(.levelChange, performanceTime: .now)
            }
        case .ready, .jump: performer.perform(.levelChange, performanceTime: .now)
        case .arrive, .leave: performer.perform(.generic, performanceTime: .now)
        }
    }

    static func score(_ cue: Cue) -> [Synth.Note] {
        switch cue {
        case .arrive:
            return [Synth.Note(at: 0, freq: 520, to: 1040, length: 0.11, decay: 0.07, gain: 0.5),
                    Synth.Note(at: 0.075, freq: 1560, length: 0.08, decay: 0.035, gain: 0.18)]
        case .leave:
            return [Synth.Note(at: 0, freq: 820, to: 380, length: 0.14, decay: 0.08, gain: 0.35)]
        case .needsYou:
            return [Synth.Note(at: 0, freq: 783.99, length: 0.5, decay: 0.16, gain: 0.45, bell: true),
                    Synth.Note(at: 0.15, freq: 1046.5, length: 0.6, decay: 0.24, gain: 0.45, bell: true)]
        case .ready:
            return [1046.5, 1318.5, 1568.0, 2093.0].enumerated().map { i, f in
                Synth.Note(at: Double(i) * 0.065, freq: f, length: 0.3, decay: i == 3 ? 0.14 : 0.07,
                           gain: i == 3 ? 0.3 : 0.38, marimba: true)
            }
        case .jump:
            return [Synth.Note(at: 0, freq: 300, to: 1300, length: 0.07, decay: 0.03, gain: 0.3)]
        }
    }
}

/// A tiny additive synth: enveloped sines, optionally pitch-swept, mixed to 16-bit mono WAV.
enum Synth {
    static let rate = 44_100.0

    struct Note {
        var at: Double
        var freq: Double
        var to: Double? = nil
        var length: Double
        /// Exponential decay time constant, in seconds.
        var decay: Double
        var gain: Double
        /// Adds inharmonic overtones that ring like a small bell.
        var bell = false
        /// Adds the bright, quickly-fading 4th partial of a wooden bar.
        var marimba = false
    }

    static func render(_ notes: [Note]) -> [Double] {
        let total = notes.map { $0.at + $0.length }.max() ?? 0
        var out = [Double](repeating: 0, count: Int(total * rate) + 1)
        for note in notes {
            let start = Int(note.at * rate)
            let count = Int(note.length * rate)
            var phase = 0.0, phase2 = 0.0, phase3 = 0.0
            for i in 0..<count where start + i < out.count {
                let t = Double(i) / rate
                let progress = t / note.length
                // Exponential glide, which sounds even to the ear.
                let f = note.to.map { note.freq * pow($0 / note.freq, progress) } ?? note.freq
                phase += 2 * .pi * f / rate
                let attack = min(1, t / 0.004)
                let release = min(1, (note.length - t) / 0.01) // no click at the end
                let env = attack * release * exp(-t / note.decay)
                var v = sin(phase)
                if note.bell {
                    phase2 += 2 * .pi * f * 2.76 / rate
                    phase3 += 2 * .pi * f * 5.4 / rate
                    v += 0.35 * sin(phase2) * exp(-t / (note.decay * 0.5)) + 0.12 * sin(phase3) * exp(-t / (note.decay * 0.25))
                }
                if note.marimba {
                    phase2 += 2 * .pi * f * 4 / rate
                    v += 0.3 * sin(phase2) * exp(-t / 0.012)
                }
                out[start + i] += v * env * note.gain
            }
        }
        return out
    }

    static func wav(_ notes: [Note]) -> Data {
        let samples = render(notes).map { Int16((max(-1, min(1, $0)) * Double(Int16.max)).rounded()) }
        var data = Data()
        func put<T: FixedWidthInteger>(_ v: T) { withUnsafeBytes(of: v.littleEndian) { data.append(contentsOf: $0) } }
        let bytes = UInt32(samples.count * 2)
        data.append(contentsOf: Array("RIFF".utf8)); put(36 + bytes)
        data.append(contentsOf: Array("WAVEfmt ".utf8)); put(UInt32(16))
        put(UInt16(1)); put(UInt16(1)); put(UInt32(rate)); put(UInt32(rate * 2)); put(UInt16(2)); put(UInt16(16))
        data.append(contentsOf: Array("data".utf8)); put(bytes)
        for s in samples { put(s) }
        return data
    }
}
