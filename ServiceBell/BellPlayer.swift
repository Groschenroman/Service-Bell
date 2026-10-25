import AVFoundation

/// Plays the bell sound. Every ring gets its own player so rapid taps overlap like a real bell.
@MainActor
final class BellPlayer {
    private let soundData: Data?
    private var activePlayers: [AVAudioPlayer] = []

    init() {
        let soundData = Bundle.main.url(forResource: "Service Bell", withExtension: "mp3")
            .flatMap { try? Data(contentsOf: $0) }
        self.soundData = soundData

        // Session setup and warm-up can block while the audio server responds, so keep them off the main thread.
        Task.detached(priority: .userInitiated) { Self.prepareAudio(soundData) }
    }

    private nonisolated static func prepareAudio(_ soundData: Data?) {
        // .playback rings even when the silent switch is on.
        try? AVAudioSession.sharedInstance().setCategory(.playback, options: .mixWithOthers)
        try? AVAudioSession.sharedInstance().setActive(true)

        // Decode once up front so the first tap has no delay.
        if let soundData { _ = try? AVAudioPlayer(data: soundData).prepareToPlay() }
    }

    func ring() {
        guard let soundData, let player = try? AVAudioPlayer(data: soundData) else { return }
        activePlayers.removeAll { !$0.isPlaying }
        activePlayers.append(player)
        player.play()
    }

    /// Fades out everything still ringing, like a hand muffling the bell. Rings started during the fade are kept.
    func silence(fadeDuration: TimeInterval = 0.25) {
        let fading = activePlayers.filter(\.isPlaying)
        activePlayers.removeAll()
        for player in fading { player.setVolume(0, fadeDuration: fadeDuration) }
        Task {
            try? await Task.sleep(for: .seconds(fadeDuration))
            fading.forEach { $0.stop() }
        }
    }
}
