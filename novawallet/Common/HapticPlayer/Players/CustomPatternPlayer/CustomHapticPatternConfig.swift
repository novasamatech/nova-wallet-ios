import Foundation

extension CustomPatternHapticPlayer {
    struct PatternConfig {
        var groupSize: Int
        var triggerCount: Int
        var progressiveIntensity: Bool
        var baseIntensity: Float
        var baseSharpness: Float

        var triggerPositions: [Int]?
    }
}

extension CustomPatternHapticPlayer.PatternConfig {
    static func withPositions(
        groupSize: Int,
        positions: [Int],
        progressiveIntensity: Bool,
        baseIntensity: Float,
        baseSharpness: Float
    ) -> Self {
        var config: Self = .init(
            groupSize: groupSize,
            triggerCount: 0, // Not used when triggerPositions is set
            progressiveIntensity: progressiveIntensity,
            baseIntensity: baseIntensity,
            baseSharpness: baseSharpness
        )
        config.triggerPositions = positions.sorted()

        return config
    }

    /// Pattern used for price chart's `seek` feature
    static var chartSeek: Self {
        withPositions(
            groupSize: 20,
            positions: [10, 12, 13, 15, 19],
            progressiveIntensity: true,
            baseIntensity: 0.7,
            baseSharpness: 0.7
        )
    }

    /// Pattern used for price chart period selection control
    static var chartPeriodControl: Self {
        .init(
            groupSize: 1,
            triggerCount: 1,
            progressiveIntensity: false,
            baseIntensity: 1.0,
            baseSharpness: 0.7
        )
    }
}
