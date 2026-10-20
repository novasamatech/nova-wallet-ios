import Foundation

public extension AnalyticsEvent {
    static func subtensorTypeSelected(
        subject: SubtensorAnalyticsSubject,
        method: StakingAnalyticsSelectionMethod,
        netuid: AnalyticsContentValue?
    ) -> AnalyticsEvent {
        subtensorEvent(.stakingTypeSelected, subject: subject, properties: [.selectionMethod: method, .netuid: netuid])
    }

    static func subtensorStakingInitiated(
        subject: SubtensorAnalyticsSubject,
        mode: StakingMode,
        validatorSource: StakingValidatorSource,
        slippage: SlippageBucket?,
        amount: AmountBucket?
    ) -> AnalyticsEvent {
        subtensorEvent(.stakingInitiated, subject: subject, properties: [
            .mode: mode,
            .validatorSource: validatorSource,
            .slippageBucket: slippage,
            .amountBucket: amount
        ])
    }

    static func subtensorStakingConfirmed(
        subject: SubtensorAnalyticsSubject,
        mode: StakingMode,
        priceMoved: Bool,
        amount: AmountBucket?
    ) -> AnalyticsEvent {
        subtensorEvent(.stakingConfirmed, subject: subject, properties: [
            .mode: mode,
            .priceMoved: priceMoved,
            .amountBucket: amount
        ])
    }

    static func subtensorStakingCompleted(
        subject: SubtensorAnalyticsSubject,
        mode: StakingMode,
        outcome: StakingCompletionOutcome,
        duration: DurationBucket,
        amount: AmountBucket?
    ) -> AnalyticsEvent {
        subtensorEvent(.stakingCompleted, subject: subject, properties: [
            .mode: mode,
            .outcome: outcome,
            .durationBucket: duration,
            .amountBucket: amount
        ])
    }

    static func subtensorStakingFailed(
        subject: SubtensorAnalyticsSubject,
        mode: StakingMode,
        failure: StakingFailureDetails
    ) -> AnalyticsEvent {
        subtensorEvent(.stakingFailed, subject: subject, properties: failure.properties.merging([.mode: mode]) { $1 })
    }

    static func subtensorStakingAbandoned(stage: StakingStage, target: StakingAnalyticsTarget?) -> AnalyticsEvent {
        AnalyticsEvent(
            name: .stakingAbandoned,
            properties: [.stage: stage, .stakingType: StakingAnalyticsType.subtensor, .target: target]
        )
    }

    static func subtensorUnstakeInitiated(
        subject: SubtensorAnalyticsSubject,
        shape: UnstakeAnalyticsShape,
        amount: AmountBucket?
    ) -> AnalyticsEvent {
        subtensorEvent(.unstakeInitiated, subject: subject, properties: shape.properties.merging([
            .amountBucket: amount
        ]) { $1 })
    }

    static func subtensorUnstakeCompleted(
        subject: SubtensorAnalyticsSubject,
        shape: UnstakeAnalyticsShape,
        outcome: StakingCompletionOutcome,
        duration: DurationBucket,
        amount: AmountBucket?
    ) -> AnalyticsEvent {
        subtensorEvent(.unstakeCompleted, subject: subject, properties: shape.properties.merging([
            .outcome: outcome,
            .durationBucket: duration,
            .amountBucket: amount
        ]) { $1 })
    }

    static func subtensorUnstakeFailed(
        subject: SubtensorAnalyticsSubject,
        shape: UnstakeAnalyticsShape,
        failure: StakingFailureDetails
    ) -> AnalyticsEvent {
        let properties = shape.properties.merging(failure.properties) { $1 }

        return subtensorEvent(.unstakeFailed, subject: subject, properties: properties)
    }

    static func rewardsClaimInitiated(
        network: AnalyticsContentValue,
        amount: AmountBucket?,
        validators: CountBucket
    ) -> AnalyticsEvent {
        subtensorEvent(.rewardsClaimInitiated, subject: .claim(on: network), properties: [
            .amountBucket: amount,
            .validatorsCountBucket: validators
        ])
    }

    static func rewardsClaimCompleted(
        network: AnalyticsContentValue,
        amount: AmountBucket?,
        duration: DurationBucket,
        claimedZero: Bool?
    ) -> AnalyticsEvent {
        subtensorEvent(.rewardsClaimCompleted, subject: .claim(on: network), properties: [
            .amountBucket: amount,
            .durationBucket: duration,
            .claimedZero: claimedZero
        ])
    }

    static func rewardsClaimFailed(network: AnalyticsContentValue, failure: StakingFailureDetails) -> AnalyticsEvent {
        subtensorEvent(.rewardsClaimFailed, subject: .claim(on: network), properties: failure.properties)
    }
}

extension AnalyticsEvent {
    static func subtensorEvent(
        _ name: AnalyticsEventName,
        subject: SubtensorAnalyticsSubject,
        properties: [AnalyticsPropertyKey: AnalyticsPropertyConvertible?]
    ) -> AnalyticsEvent {
        let subjectProperties: [AnalyticsPropertyKey: AnalyticsPropertyConvertible?] = [
            .stakingType: StakingAnalyticsType.subtensor,
            .network: subject.network,
            .target: subject.target
        ]

        return AnalyticsEvent(name: name, properties: subjectProperties.merging(properties) { $1 })
    }
}

private extension SubtensorAnalyticsSubject {
    static func claim(on network: AnalyticsContentValue) -> SubtensorAnalyticsSubject {
        SubtensorAnalyticsSubject(network: network, target: .root)
    }
}

private extension StakingFailureDetails {
    var properties: [AnalyticsPropertyKey: AnalyticsPropertyConvertible?] {
        [.reason: reason, .stage: stage, .retryable: retryable]
    }
}

private extension UnstakeAnalyticsShape {
    var properties: [AnalyticsPropertyKey: AnalyticsPropertyConvertible?] {
        [.mode: mode, .hotkeyCountBucket: hotkeys, .hasLocked: hasLocked, .slippageBucket: slippage]
    }
}
