import Foundation

public extension AnalyticsEvent {
    static func appOpened(isFirstLaunch: Bool) -> AnalyticsEvent {
        AnalyticsEvent(name: .appOpened, properties: [.isFirstLaunch: isFirstLaunch])
    }

    static func sessionStarted() -> AnalyticsEvent {
        AnalyticsEvent(name: .sessionStarted)
    }

    static func sessionEnded(duration: TimeInterval) -> AnalyticsEvent {
        AnalyticsEvent(
            name: .sessionEnded,
            properties: [.durationBucket: DurationBucket(duration: duration)]
        )
    }
}
