import Foundation

public extension AnalyticsEvent {
    static func subtensorStakingBlocked(
        flow: StakingFlow,
        reason: StakingBlockedReason,
        walletType: AnalyticsWalletType?,
        target: StakingAnalyticsTarget?
    ) -> AnalyticsEvent {
        AnalyticsEvent(
            name: .stakingBlocked,
            properties: [
                .stakingType: StakingAnalyticsType.subtensor,
                .flow: flow,
                .reason: reason,
                .walletType: walletType,
                .target: target
            ]
        )
    }

    static func subtensorValidationShown(
        flow: StakingFlow,
        kind: StakingValidationKind,
        stage: StakingValidationStage,
        outcome: StakingValidationOutcome,
        target: StakingAnalyticsTarget?
    ) -> AnalyticsEvent {
        AnalyticsEvent(
            name: .stakingValidationShown,
            properties: [
                .stakingType: StakingAnalyticsType.subtensor,
                .flow: flow,
                .kind: kind,
                .stage: stage,
                .outcome: outcome,
                .target: target
            ]
        )
    }

    static func slippageChanged(
        method: SlippageChangeMethod,
        slippage: SlippageBucket,
        warning: SlippageWarning
    ) -> AnalyticsEvent {
        AnalyticsEvent(
            name: .slippageChanged,
            properties: [.method: method, .slippageBucket: slippage, .warning: warning]
        )
    }

    static func subnetListOpened(
        source: SubnetListSource,
        sort: SubnetSortKey,
        hideThinPools: Bool
    ) -> AnalyticsEvent {
        AnalyticsEvent(
            name: .subnetListOpened,
            properties: [.source: source, .sort: sort, .hideThinPools: hideThinPools]
        )
    }

    static func subnetListInteracted(_ interaction: SubnetListInteraction) -> AnalyticsEvent {
        AnalyticsEvent(
            name: .subnetListInteracted,
            properties: [.action: interaction.action, .value: interaction.value]
        )
    }

    static func subnetDetailsOpened(
        netuid: AnalyticsContentValue?,
        source: SubnetDetailsSource,
        period: AnalyticsPricePeriod?
    ) -> AnalyticsEvent {
        AnalyticsEvent(
            name: .subnetDetailsOpened,
            properties: [.netuid: netuid, .source: source, .period: period]
        )
    }

    static func validatorChanged(
        target: StakingAnalyticsTarget,
        source: ValidatorChangeSource,
        unusualApyFilter: Bool
    ) -> AnalyticsEvent {
        AnalyticsEvent(
            name: .validatorChanged,
            properties: [.target: target, .source: source, .unusualApyFilter: unusualApyFilter]
        )
    }

    static func subtensorPortfolioOpened(
        source: StakingPortfolioSource,
        positions: CountBucket,
        hasRoot: Bool,
        chartState: StakingChartState?
    ) -> AnalyticsEvent {
        AnalyticsEvent(
            name: .stakingPortfolioOpened,
            properties: [
                .stakingType: StakingAnalyticsType.subtensor,
                .source: source,
                .positionsCountBucket: positions,
                .hasRoot: hasRoot,
                .chartState: chartState
            ]
        )
    }

    static func subtensorPositionOpened(
        target: StakingAnalyticsTarget,
        netuid: AnalyticsContentValue?,
        hasHold: Bool,
        hasLock: Bool,
        rewardsState: StakingRewardsState
    ) -> AnalyticsEvent {
        AnalyticsEvent(
            name: .stakingPositionOpened,
            properties: [
                .stakingType: StakingAnalyticsType.subtensor,
                .target: target,
                .netuid: netuid,
                .hasHold: hasHold,
                .hasLock: hasLock,
                .rewardsState: rewardsState
            ]
        )
    }

    static func subtensorResultAction(
        _ action: StakingResultAction,
        flow: StakingFlow,
        target: StakingAnalyticsTarget
    ) -> AnalyticsEvent {
        AnalyticsEvent(
            name: .stakingResultAction,
            properties: [
                .stakingType: StakingAnalyticsType.subtensor,
                .action: action,
                .flow: flow,
                .target: target
            ]
        )
    }

    static func bittensorDataFailed(
        endpoint: BittensorDataEndpoint,
        reason: BittensorDataFailureReason,
        screen: BittensorScreen,
        retryable: Bool
    ) -> AnalyticsEvent {
        AnalyticsEvent(
            name: .bittensorDataFailed,
            properties: [.endpoint: endpoint, .reason: reason, .screen: screen, .retryable: retryable]
        )
    }

    static func bittensorDataRetryTapped(endpoint: BittensorDataEndpoint, screen: BittensorScreen) -> AnalyticsEvent {
        AnalyticsEvent(name: .bittensorDataRetryTapped, properties: [.endpoint: endpoint, .screen: screen])
    }
}
