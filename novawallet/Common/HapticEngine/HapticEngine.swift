import Foundation

protocol HapticEngine {
    /// Reset the engine to start a new pattern sequence
    func reset()

    /// Trigger haptic feedback if needed based on configuration
    func triggerHapticFeedback(
        customIntensity: Float?,
        customSharpness: Float?
    )

    /// Play a simple transient haptic feedback
    func playTransientHaptic(
        intensity: Float,
        sharpness: Float
    )

    /// Play a continuous haptic with the specified duration
    func playContinuousHaptic(
        intensity: Float,
        sharpness: Float,
        duration: TimeInterval
    )

    /// Generate a sequence of haptic events for creating complex patterns
    func playHapticSequence(
        intensities: [Float],
        sharpness: [Float]?,
        spacing: TimeInterval
    )
}

extension HapticEngine {
    /// Trigger haptic feedback if needed based on configuration
    func triggerHapticFeedback() {
        triggerHapticFeedback(
            customIntensity: nil,
            customSharpness: nil
        )
    }

    /// Process multiple values sequentially
    func triggerHapticFeedbacks(
        count: Int,
        customIntensity: Float? = nil,
        customSharpness: Float? = nil
    ) {
        (0 ..< count).forEach { _ in
            triggerHapticFeedback(
                customIntensity: customIntensity,
                customSharpness: customSharpness
            )
        }
    }

    /// Play a crescendo pattern (gradually increasing intensity)
    func playCrescendo(duration: TimeInterval = 0.6) {
        let steps = 4
        let intensities = (0 ..< steps).map { Float($0 + 1) / Float(steps) }
        let sharpness = intensities.map { min($0 + 0.2, 1.0) }

        playHapticSequence(
            intensities: intensities,
            sharpness: sharpness,
            spacing: duration / TimeInterval(steps)
        )
    }

    /// Play a decrescendo pattern (gradually decreasing intensity)
    func playDecrescendo(duration: TimeInterval = 0.6) {
        let steps = 4
        let intensities = (0 ..< steps).map { Float(steps - $0) / Float(steps) }
        let sharpness = intensities.map { min($0 + 0.2, 1.0) }

        playHapticSequence(
            intensities: intensities,
            sharpness: sharpness,
            spacing: duration / TimeInterval(steps)
        )
    }

    /// Play a heartbeat pattern
    func playHeartbeat() {
        playHapticSequence(
            intensities: [0.8, 0.4, 1.0],
            sharpness: [0.5, 0.3, 0.6],
            spacing: 0.15
        )
    }

    /// Play a double-tap pattern
    func playDoubleTap() {
        playHapticSequence(
            intensities: [0.7, 0.7],
            sharpness: [0.5, 0.5],
            spacing: 0.1
        )
    }

    /// Play a success pattern
    func playSuccess() {
        playHapticSequence(
            intensities: [0.6, 0.8, 1.0],
            sharpness: [0.3, 0.5, 0.7],
            spacing: 0.1
        )
    }

    /// Play an error/failure pattern
    func playError() {
        playHapticSequence(
            intensities: [1.0, 0.7, 0.3],
            sharpness: [0.9, 0.8, 0.7],
            spacing: 0.07
        )
    }

    /// Play a warning pattern
    func playWarning() {
        playHapticSequence(
            intensities: [0.8, 0.0, 0.8],
            sharpness: [0.6, 0.0, 0.6],
            spacing: 0.15
        )
    }
}
