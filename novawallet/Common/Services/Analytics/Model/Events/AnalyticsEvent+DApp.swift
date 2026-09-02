import Foundation

extension AnalyticsEvent {
    static func dappOpened(
        host: AnalyticsContentValue,
        source: DAppOpenSource,
        isKnown: Bool
    ) -> AnalyticsEvent {
        AnalyticsEvent(
            name: .dappOpened,
            properties: [.dappHost: host, .source: source, .isKnownDapp: isKnown]
        )
    }

    static func signRequestShown(
        source: SignSource,
        method: AnalyticsContentValue,
        chain: AnalyticsContentValue
    ) -> AnalyticsEvent {
        signingEvent(name: .signRequestShown, source: source, method: method, chain: chain)
    }

    static func signApproved(
        source: SignSource,
        method: AnalyticsContentValue,
        chain: AnalyticsContentValue
    ) -> AnalyticsEvent {
        signingEvent(name: .signApproved, source: source, method: method, chain: chain)
    }

    static func signRejected(
        source: SignSource,
        method: AnalyticsContentValue,
        chain: AnalyticsContentValue
    ) -> AnalyticsEvent {
        signingEvent(name: .signRejected, source: source, method: method, chain: chain)
    }

    static func signFailed(
        source: SignSource,
        method: AnalyticsContentValue,
        chain: AnalyticsContentValue,
        reason: SignFailureReason
    ) -> AnalyticsEvent {
        AnalyticsEvent(
            name: .signFailed,
            properties: [.source: source, .method: method, .chain: chain, .reason: reason]
        )
    }
}

private extension AnalyticsEvent {
    static func signingEvent(
        name: AnalyticsEventName,
        source: SignSource,
        method: AnalyticsContentValue,
        chain: AnalyticsContentValue
    ) -> AnalyticsEvent {
        AnalyticsEvent(
            name: name,
            properties: [.source: source, .method: method, .chain: chain]
        )
    }
}
