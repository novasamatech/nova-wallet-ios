import Foundation

public extension AnalyticsEvent {
    static func onboardingStarted(source: OnboardingSource) -> AnalyticsEvent {
        AnalyticsEvent(name: .onboardingStarted, properties: [.source: source])
    }

    static func walletImportMethodSelected(method: WalletCreationMethod) -> AnalyticsEvent {
        AnalyticsEvent(name: .walletImportMethodSelected, properties: [.method: method])
    }

    static func walletCreationStarted() -> AnalyticsEvent {
        AnalyticsEvent(name: .walletCreationStarted)
    }

    static func walletCreationCompleted(
        method: WalletCreationMethod,
        duration: TimeInterval?
    ) -> AnalyticsEvent {
        AnalyticsEvent(
            name: .walletCreationCompleted,
            properties: [
                .method: method,
                .durationBucket: duration.map { DurationBucket(duration: $0) }
            ]
        )
    }

    static func walletCreationAbandoned(lastStep: WalletCreationStep) -> AnalyticsEvent {
        AnalyticsEvent(name: .walletCreationAbandoned, properties: [.lastStep: lastStep])
    }
}
