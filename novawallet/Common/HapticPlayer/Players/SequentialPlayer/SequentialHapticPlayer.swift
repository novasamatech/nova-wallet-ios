import Foundation

final class SequentialHapticPlayer {
    private let engine: HapticEngine
    private let config: PatternConfig

    init(
        engine: HapticEngine,
        config: PatternConfig
    ) {
        self.engine = engine
        self.config = config
    }
}

// MARK: HapticPlayer

extension SequentialHapticPlayer: HapticPlayer {
    func play() {
        engine.generateHapticSequence(
            intensities: config.intensities,
            sharpness: config.sharpness,
            spacing: config.spacing
        )
    }
}
