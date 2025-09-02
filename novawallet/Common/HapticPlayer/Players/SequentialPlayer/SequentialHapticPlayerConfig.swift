import Foundation

extension SequentialHapticPlayer {
    struct PatternConfig {
        var intensities: [Float]
        var sharpness: [Float]
        var spacing: TimeInterval
    }
}

extension SequentialHapticPlayer.PatternConfig {
    /// Gradually increasing intensity
    static var crescendo: Self {
        let steps = 4
        let duration: TimeInterval = 0.6
        let intensities = (0 ..< steps).map { Float($0 + 1) / Float(steps) }
        let sharpness = intensities.map { min($0 + 0.2, 1.0) }

        return .init(
            intensities: intensities,
            sharpness: sharpness,
            spacing: duration / TimeInterval(steps)
        )
    }

    /// Gradually decreasing intensity
    static var decrescendo: Self {
        let steps = 4
        let duration: TimeInterval = 0.6
        let intensities = (0 ..< steps).map { Float(steps - $0) / Float(steps) }
        let sharpness = intensities.map { min($0 + 0.2, 1.0) }

        return .init(
            intensities: intensities,
            sharpness: sharpness,
            spacing: duration / TimeInterval(steps)
        )
    }

    /// Heartbeat pattern
    static var heartbeat: Self {
        .init(
            intensities: [0.8, 0.4, 1.0],
            sharpness: [0.5, 0.3, 0.6],
            spacing: 0.2
        )
    }

    /// Double-tap pattern
    static var doubleTap: Self {
        .init(
            intensities: [0.7, 0.7],
            sharpness: [0.5, 0.5],
            spacing: 0.15
        )
    }

    /// Single-tap pattern
    static var singleTap: Self {
        .init(
            intensities: [0.7],
            sharpness: [0.7],
            spacing: 0
        )
    }

    /// Success pattern
    static var success: Self {
        .init(
            intensities: [0.6, 0.8, 1.0],
            sharpness: [0.3, 0.5, 0.7],
            spacing: 0.1
        )
    }

    /// Error/failure pattern
    static var error: Self {
        .init(
            intensities: [1.0, 0.7, 0.3],
            sharpness: [0.9, 0.8, 0.7],
            spacing: 0.07
        )
    }

    /// Warning pattern
    static var warning: Self {
        .init(
            intensities: [0.8, 0.0, 0.8],
            sharpness: [0.6, 0.0, 0.6],
            spacing: 0.15
        )
    }
}
