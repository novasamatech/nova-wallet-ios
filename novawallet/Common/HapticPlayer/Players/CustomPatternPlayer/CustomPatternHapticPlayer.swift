import Foundation
import CoreHaptics

final class CustomPatternHapticPlayer {
    private let engine: HapticEngine
    private let config: PatternConfig

    private var valueCounter = 0

    init(
        engine: HapticEngine,
        config: PatternConfig
    ) {
        self.engine = engine
        self.config = config
    }
}

// MARK: Private

private extension CustomPatternHapticPlayer {
    func playHaptic(using triggerPositions: [Int]) {
        let currentPosition = valueCounter == 0
            ? config.groupSize
            : valueCounter

        guard let positionIndex = triggerPositions.firstIndex(of: currentPosition) else { return }

        let intensityFactor: Float = config.progressiveIntensity
            ? Float(positionIndex + 1) / Float(triggerPositions.count)
            : 1.0

        engine.generateTransientHaptic(
            intensity: config.baseIntensity * intensityFactor,
            sharpness: config.baseSharpness
        )
    }

    func playHaptic() {
        let position = valueCounter
        let triggerStartPosition = config.groupSize - config.triggerCount

        guard position >= triggerStartPosition else { return }

        let triggerPosition = if position == 0 {
            config.triggerCount
        } else {
            position - triggerStartPosition + 1
        }

        let intensityFactor: Float = if config.progressiveIntensity, config.triggerCount > 0 {
            Float(triggerPosition) / Float(config.triggerCount)
        } else {
            1.0
        }

        engine.generateTransientHaptic(
            intensity: config.baseIntensity * intensityFactor,
            sharpness: config.baseSharpness
        )
    }
}

// MARK: ProgressiveHapticPlayer

extension CustomPatternHapticPlayer: ProgressiveHapticPlayer {
    func reset() {
        valueCounter = 0
    }

    func play() {
        valueCounter = (valueCounter + 1) % config.groupSize

        if let triggerPositions = config.triggerPositions {
            playHaptic(using: triggerPositions)
        } else {
            playHaptic()
        }
    }
}
