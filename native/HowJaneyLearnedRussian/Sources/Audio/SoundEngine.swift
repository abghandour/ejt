import AVFoundation

/// Procedural sound playback. Each `SoundEffect` is rendered once into a PCM
/// buffer from its layered recipe — FM bells, band-passed noise, pitch glides
/// — and played through a small player pool into a room reverb, which is what
/// separates "beep" from "sound design".
/// Uses the `.ambient` session so the ringer switch and other audio are respected.
@Observable
final class SoundEngine {
    var isEnabled = true

    @ObservationIgnored private let engine = AVAudioEngine()
    @ObservationIgnored private let reverb = AVAudioUnitReverb()
    /// Players fan into this mixer; the reverb has only ONE input bus, so
    /// connecting players to it directly disconnects all but the last one.
    @ObservationIgnored private let submix = AVAudioMixerNode()
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
        guard engine.isRunning, !players.isEmpty else { return }
        let player = players[nextPlayer]
        nextPlayer = (nextPlayer + 1) % players.count
        // Never start a player whose graph connection was dropped — that
        // throws an unrecoverable NSException.
        guard player.engine != nil,
              !engine.outputConnectionPoints(for: player, outputBus: 0).isEmpty
        else { return }
        player.scheduleBuffer(buffer)
        if !player.isPlaying { player.play() }
    }

    // MARK: - Setup

    private func prepare() async {
        buffers = await Self.renderAllBuffers()

        // Debug hook: write every rendered buffer as WAV for inspection.
        if ProcessInfo.processInfo.arguments.contains("-dump-sounds") {
            dumpBuffers()
        }

        try? AVAudioSession.sharedInstance().setCategory(.ambient)

        guard let format = AVAudioFormat(standardFormatWithSampleRate: Self.sampleRate, channels: 1) else { return }

        // Players → submix → reverb → main mixer. A touch of room keeps short
        // synthetic sounds from feeling dry and "chip-tune".
        reverb.loadFactoryPreset(.mediumRoom)
        reverb.wetDryMix = 22
        engine.attach(submix)
        engine.attach(reverb)
        engine.connect(reverb, to: engine.mainMixerNode, format: format)
        engine.connect(submix, to: reverb, format: format)

        for _ in 0..<6 {
            let player = AVAudioPlayerNode()
            engine.attach(player)
            engine.connect(player, to: submix, format: format)
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

        // Route/format changes can silently stop the engine; restart lazily.
        NotificationCenter.default.addObserver(
            forName: .AVAudioEngineConfigurationChange,
            object: engine,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.isRunning = false
            }
        }
    }

    private func dumpBuffers() {
        let directory = URL.documentsDirectory.appending(path: "sound-dump")
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        for (effect, buffer) in buffers {
            let name = String(describing: effect)
                .replacing("(", with: "-").replacing(")", with: "")
                .replacing(":", with: "").replacing(" ", with: "")
            let url = directory.appending(path: "\(name).wav")
            try? FileManager.default.removeItem(at: url)
            if let file = try? AVAudioFile(forWriting: url, settings: buffer.format.settings) {
                try? file.write(from: buffer)
            }
        }
    }

    private func startEngineIfNeeded() {
        if isRunning, engine.isRunning { return }
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
            .deselect, .correct, .wrong, .penalty, .boardClear, .gameEnd,
            .tick, .explode, .newWord, .slash,
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

        var noiseRNG = SeedEngine(seed: 0x5EED)

        for layer in effect.layers {
            renderLayer(layer, into: samples, totalFrames: Int(frameCount), noiseRNG: &noiseRNG)
        }

        // Gentle soft-clip guard against stacked layers.
        for i in 0..<Int(frameCount) {
            samples[i] = max(-0.95, min(0.95, samples[i]))
        }
        return buffer
    }

    private nonisolated static func renderLayer(
        _ layer: SoundEffect.Layer,
        into samples: UnsafeMutablePointer<Float>,
        totalFrames: Int,
        noiseRNG: inout SeedEngine
    ) {
        let dt = 1.0 / sampleRate
        let startFrame = Int(layer.start * sampleRate)
        let frames = Int(layer.duration * sampleRate)
        guard frames > 1 else { return }

        let attackFrames = max(1, Int(layer.attack * sampleRate))
        // Exponential decay reaching about −60 dB by the layer's end.
        let decayRate = 6.9 / max(layer.duration - layer.attack, 0.005)

        // Phase accumulators (glide-safe frequency changes).
        var carrierPhase = 0.0
        var modPhase = 0.0

        // Chamberlin state-variable filter state for noise layers.
        var low = 0.0
        var band = 0.0

        for n in 0..<frames {
            let frame = startFrame + n
            guard frame < totalFrames else { break }
            let t = Double(n) * dt
            let progress = t / layer.duration

            // Frequency glide (linear).
            let frequency: Double
            if let endFrequency = layer.endFrequency {
                frequency = layer.frequency + (endFrequency - layer.frequency) * progress
            } else {
                frequency = layer.frequency
            }

            let attack = n < attackFrames ? Double(n) / Double(attackFrames) : 1
            let decay = exp(-decayRate * max(0, t - layer.attack))
            let envelope = attack * decay

            var sample = 0.0
            switch layer.timbre {
            case .bell(let modRatio, let modIndex):
                // FM bell: modulation index decays so the attack glints and
                // the tail turns pure — the "glass" sound.
                let index = modIndex * exp(-8.0 * progress)
                carrierPhase += 2 * .pi * frequency * dt
                modPhase += 2 * .pi * frequency * modRatio * dt
                sample = sin(carrierPhase + index * sin(modPhase))
            case .sine:
                carrierPhase += 2 * .pi * frequency * dt
                sample = sin(carrierPhase)
            case .noise(let q):
                let white = noiseRNG.next() * 2 - 1
                // Chamberlin SVF band-pass with the swept center frequency.
                let f = min(1.5, 2 * sin(.pi * frequency / sampleRate))
                low += f * band
                let high = white - low - (1 / q) * band
                band += f * high
                sample = band
            }

            samples[frame] += Float(sample * envelope * layer.gain)
        }
    }
}
