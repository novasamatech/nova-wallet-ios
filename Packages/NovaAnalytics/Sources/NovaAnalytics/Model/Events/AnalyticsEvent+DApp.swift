import Foundation

public extension AnalyticsEvent {
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

    /// `host` is sent for the notice only; the search banner has no site yet and the typed
    /// query must never be recorded.
    static func dappStakingPromptShown(
        placement: DAppStakingPromptPlacement,
        kind: DAppStakingPromptKind,
        host: AnalyticsContentValue?
    ) -> AnalyticsEvent {
        AnalyticsEvent(
            name: .dappStakingPromptShown,
            properties: [.placement: placement, .kind: kind, .dappHost: host]
        )
    }

    static func dappStakingPromptAction(
        placement: DAppStakingPromptPlacement,
        kind: DAppStakingPromptKind,
        action: DAppStakingPromptAction,
        host: AnalyticsContentValue?
    ) -> AnalyticsEvent {
        AnalyticsEvent(
            name: .dappStakingPromptAction,
            properties: [.placement: placement, .kind: kind, .action: action, .dappHost: host]
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
