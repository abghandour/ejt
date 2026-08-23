import AVFoundation

/// Procedural sound playback: renders each `SoundEffect` once into a PCM buffer
/// (soft attack, exponential decay, gentle harmonics — one timbre family),
/// then plays buffers through a small pool of player nodes.
/// Uses the `.ambient` session so the ringer switch and other audio are respected.
@Observable
final class SoundEngine {
    var isEnabled = true

    @ObservationIgnored private let engine = AVAudioEngine()
    @ObservationIgnored private var players: [AVAudioPlayerNode] = []
    @ObservationIgnored private var nextPlayer = 0
    @ObservationIgnored private var buffers: [SoundEffect: AVAudioPCMBuffer] = [:]
    @ObservationIgnored private var isRunning = false

    nonisolated static let sampleRate: Double = 44_100

    init() {
        Task { await prepare() }
    }

    func play(_ effect: SoundEffect) {
        guard isEnabled, let buffer = buffers[effect] else { return }
        startEngineIfNeeded()
        guard isRunning, !players.isEmpty else { return }
        let player = players[nextPlayer]
        nextPlayer = (nextPlayer + 1) % players.count
        player.scheduleBuffer(buffer)
        if !player.isPlaying { player.play() }
    }

    // MARK: - Setup

    private func prepare() async {
        buffers = await Self.renderAllBuffers()

        try? AVAudioSession.sharedInstance().setCategory(.ambient)

        guard let format = AVAudioFormat(standardFormatWithSampleRate: Self.sampleRate, channels: 1) else { return }
        for _ in 0..<6 {
            let player = AVAudioPlayerNode()
            engine.attach(player)
            engine.connect(player, to: engine.mainMixerNode, format: format)
            players.append(player)
        }

        NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(),
            queue: .main
        ) { [weak self] notification in
            let ended = (notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt)
                .flatMap(AVAudioSession.InterruptionType.init) == .ended
            Task { @MainActor [weak self] in
                if ended { self?.restartAfterInterruption() }
                else { self?.isRunning = false }
            }
        }
    }

    private func startEngineIfNeeded() {
        guard !isRunning else { return }
        do {
            try AVAudioSession.sharedInstance().setActive(true)
            try engine.start()
            isRunning = true
        } catch {
            isRunning = false
        }
    }

    private func restartAfterInterruption() {
        isRunning = false
        startEngineIfNeeded()
    }

    // MARK: - Rendering

    @concurrent
    private nonisolated static func renderAllBuffers() async -> [SoundEffect: AVAudioPCMBuffer] {
        var effects: [SoundEffect] = [
            .deselect, .correct, .wrong, .penalty, .boardClear, .gameEnd, .tick, .explode, .newWord, .slash,
        ]
        effects.append(contentsOf: (0..<SoundEffect.maxSelectSteps).map { .select(step: $0) })

        var result: [SoundEffect: AVAudioPCMBuffer] = [:]
        for effect in effects {
            if let buffer = render(effect) {
                result[effect] = buffer
            }
        }
        return result
    }

    private nonisolated static func render(_ effect: SoundEffect) -> AVAudioPCMBuffer? {
        let frameCount = AVAudioFrameCount(effect.length * sampleRate)
        guard
            frameCount > 0,
            let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1),
            let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount),
            let samples = buffer.floatChannelData?[0]
        else { return nil }
        buffer.frameLength = frameCount

        for i in 0..<Int(frameCount) {
            samples[i] = 0
        }

        for note in effect.notes {
            let startFrame = Int(note.start * sampleRate)
            let noteFrames = Int(note.duration * sampleRate)
            let attackFrames = max(1, Int(0.006 * sampleRate))
            let twoPi = 2.0 * Double.pi

            for n in 0..<noteFrames {
                let frame = startFrame + n
                guard frame < Int(frameCount) else { break }
                let t = Double(n) / sampleRate

                // Envelope: fast linear attack, exponential decay to silence.
                let attack = n < attackFrames ? Double(n) / Double(attackFrames) : 1
                let decay = exp(-5.5 * Double(n) / Double(noteFrames))
                let envelope = attack * decay

                // Timbre: fundamental + soft even/odd harmonics scaled by brightness.
                let phase = twoPi * note.frequency * t
                var sample = sin(phase)
                sample += 0.35 * note.brightness * sin(2 * phase)
                sample += 0.20 * note.brightness * sin(3 * phase)
                sample /= 1 + 0.55 * note.brightness

                samples[Int(frame)] += Float(sample * envelope * note.gain)
            }
        }

        // Safety clamp against overlapping notes clipping.
        for i in 0..<Int(frameCount) {
            samples[i] = max(-0.95, min(0.95, samples[i]))
        }
        return buffer
    }
}
