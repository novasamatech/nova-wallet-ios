import Foundation

protocol HapticEngine {
    /// Play a simple transient haptic feedback
    func generateTransientHaptic(
        intensity: Float,
        sharpness: Float
    )

    /// Generate a continuous haptic with the specified duration
    func generateContinuousHaptic(
        intensity: Float,
        sharpness: Float,
        duration: TimeInterval
    )

    /// Generate a sequence of haptic events for creating complex patterns
    func generateHapticSequence(
        intensities: [Float],
        sharpness: [Float],
        spacing: TimeInterval
    )
}
