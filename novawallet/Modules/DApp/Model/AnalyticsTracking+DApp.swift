import Foundation
import NovaAnalytics

extension AnalyticsTracking {
    func trackDAppOpened(
        url: URL,
        source: DAppOpenSource,
        isKnown: Bool
    ) {
        let event = AnalyticsContentValue.dappHost(url).map { host in
            AnalyticsEvent.dappOpened(
                host: host,
                source: source,
                isKnown: isKnown
            )
        }

        trackAnalytics(event)
    }

    // `kind` is optional so that a site or a query without a prompt emits nothing
    func trackDAppStakingPromptShown(
        placement: DAppStakingPromptPlacement,
        kind: DAppStakingPromptKind?,
        host: AnalyticsContentValue?
    ) {
        let event = kind.map { kind in
            AnalyticsEvent.dappStakingPromptShown(placement: placement, kind: kind, host: host)
        }

        trackAnalytics(event)
    }

    func trackDAppStakingPromptAction(
        placement: DAppStakingPromptPlacement,
        kind: DAppStakingPromptKind?,
        action: DAppStakingPromptAction,
        host: AnalyticsContentValue?
    ) {
        let event = kind.map { kind in
            AnalyticsEvent.dappStakingPromptAction(
                placement: placement,
                kind: kind,
                action: action,
                host: host
            )
        }

        trackAnalytics(event)
    }
}

extension DAppStakingSiteKind {
    var analyticsPromptKind: DAppStakingPromptKind? {
        switch self {
        case .bittensor:
            return .bittensor
        case .thirdPartyStaking:
            return .staking
        case .none:
            return nil
        }
    }
}

extension DAppStakingQueryKind {
    var analyticsPromptKind: DAppStakingPromptKind? {
        switch self {
        case .bittensor:
            return .bittensor
        case .staking:
            return .staking
        case .none:
            return nil
        }
    }
}
