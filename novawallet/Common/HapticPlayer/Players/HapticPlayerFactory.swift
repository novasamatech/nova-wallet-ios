import Foundation
import Foundation_iOS

enum HapticPlayerFactory {
    static func createProgressivePlayer(
        patternConfiguration: CustomPatternHapticPlayer.PatternConfig
    ) -> ProgressiveHapticPlayer {
        CustomPatternHapticPlayer(
            engine: createEngine(),
            config: patternConfiguration
        )
    }

    static func createHapticPlayer(
        patternConfiguration: SequentialHapticPlayer.PatternConfig
    ) -> HapticPlayer {
        SequentialHapticPlayer(
            engine: createEngine(),
            config: patternConfiguration
        )
    }

    private static func createEngine() -> HapticEngine {
        CoreHapticEngine(
            logger: Logger.shared,
            applicationHandler: ApplicationHandler()
        )
    }
}
