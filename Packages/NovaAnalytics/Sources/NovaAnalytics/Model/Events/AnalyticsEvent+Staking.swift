import Foundation

public extension AnalyticsEvent {
    static func stakingFlowOpened(
        network: AnalyticsContentValue,
        source: StakingFlowSource
    ) -> AnalyticsEvent {
        AnalyticsEvent(
            name: .stakingFlowOpened,
            properties: [.network: network, .source: source]
        )
    }

    static func stakingTypeSelected(
        type: StakingAnalyticsType,
        network: AnalyticsContentValue
    ) -> AnalyticsEvent {
        AnalyticsEvent(
            name: .stakingTypeSelected,
            properties: [.stakingType: type, .network: network]
        )
    }

    static func stakingInitiated(
        type: StakingAnalyticsType,
        network: AnalyticsContentValue,
        amount: Decimal,
        rate: Decimal?
    ) -> AnalyticsEvent {
        stakingAmountEvent(name: .stakingInitiated, type: type, network: network, amount: amount, rate: rate)
    }

    static func stakingConfirmed(
        type: StakingAnalyticsType,
        network: AnalyticsContentValue,
        amount: Decimal,
        rate: Decimal?
    ) -> AnalyticsEvent {
        stakingAmountEvent(name: .stakingConfirmed, type: type, network: network, amount: amount, rate: rate)
    }

    static func stakingCompleted(
        type: StakingAnalyticsType,
        network: AnalyticsContentValue,
        amount: Decimal,
        rate: Decimal?
    ) -> AnalyticsEvent {
        stakingAmountEvent(name: .stakingCompleted, type: type, network: network, amount: amount, rate: rate)
    }

    static func stakingFailed(
        type: StakingAnalyticsType,
        network: AnalyticsContentValue,
        reason: TransactionFailureReason
    ) -> AnalyticsEvent {
        stakingFailureEvent(name: .stakingFailed, type: type, network: network, reason: reason)
    }

    static func stakingAbandoned(stage: StakingStage) -> AnalyticsEvent {
        AnalyticsEvent(name: .stakingAbandoned, properties: [.stage: stage])
    }

    static func unstakeInitiated(
        type: StakingAnalyticsType,
        network: AnalyticsContentValue,
        amount: Decimal,
        rate: Decimal?
    ) -> AnalyticsEvent {
        stakingAmountEvent(name: .unstakeInitiated, type: type, network: network, amount: amount, rate: rate)
    }

    static func unstakeCompleted(
        type: StakingAnalyticsType,
        network: AnalyticsContentValue,
        amount: Decimal,
        rate: Decimal?
    ) -> AnalyticsEvent {
        stakingAmountEvent(name: .unstakeCompleted, type: type, network: network, amount: amount, rate: rate)
    }

    static func unstakeFailed(
        type: StakingAnalyticsType,
        network: AnalyticsContentValue,
        reason: TransactionFailureReason
    ) -> AnalyticsEvent {
        stakingFailureEvent(name: .unstakeFailed, type: type, network: network, reason: reason)
    }
}

private extension AnalyticsEvent {
    static func stakingAmountEvent(
        name: AnalyticsEventName,
        type: StakingAnalyticsType,
        network: AnalyticsContentValue,
        amount: Decimal,
        rate: Decimal?
    ) -> AnalyticsEvent {
        AnalyticsEvent(
            name: name,
            properties: [
                .stakingType: type,
                .network: network,
                .amountBucket: AmountBucket(amount: amount, rate: rate)
            ]
        )
    }

    static func stakingFailureEvent(
        name: AnalyticsEventName,
        type: StakingAnalyticsType,
        network: AnalyticsContentValue,
        reason: TransactionFailureReason
    ) -> AnalyticsEvent {
        AnalyticsEvent(
            name: name,
            properties: [.stakingType: type, .network: network, .reason: reason]
        )
    }
}
