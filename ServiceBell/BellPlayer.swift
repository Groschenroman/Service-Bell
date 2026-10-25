import AVFoundation

/// Plays the bell sound. Every ring gets its own player so rapid taps overlap like a real bell.
@MainActor
final class BellPlayer {
    private let soundData: Data?
    private var activePlayers: [AVAudioPlayer] = []

    init() {
        // .playback rings even when the silent switch is on.
        try? AVAudioSession.sharedInstance().setCategory(.playback, options: .mixWithOthers)
        try? AVAudioSession.sharedInstance().setActive(true)

        soundData = Bundle.main.url(forResource: "Service Bell", withExtension: "mp3")
            .flatMap { try? Data(contentsOf: $0) }

        // Decode once up front so the first tap has no delay.
        if let soundData { _ = try? AVAudioPlayer(data: soundData).prepareToPlay() }
    }

    func ring() {
        guard let soundData, let player = try? AVAudioPlayer(data: soundData) else { return }
        activePlayers.removeAll { !$0.isPlaying }
        activePlayers.append(player)
        player.play()
    }
}
