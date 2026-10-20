import Foundation

struct SubtensorUnstakeValidatingDependencies {
    let netuid: UInt16
    let accountId: AccountId
    let hotkey: AccountId?
    let amount: Balance?
    let positionAlpha: Balance?
    let positions: [AccountId: Balance]
    let plan: SubtensorUnstakePlan?
    let groupHotkeys: [AccountId: SubtensorGroupHotkeyInfo]?
    let availability: SubtensorPallet.StakeAvailability?
    let balance: AssetBalance?
    let fee: ExtrinsicFeeProtocol?
    let existentialDeposit: Balance?
    let preflight: SubtensorPreflight?
    let holds: [AccountId: SubtensorRootHold]?
    let currentBlock: BlockNumber?
    let assetDisplayInfo: AssetBalanceDisplayInfo
    let syncFailed: Bool
    let onFeeRefresh: () -> Void
    let onPreflightRefresh: () -> Void
    let onPositionsRefresh: () -> Void
    var onGroupHotkeysRefresh: (() -> Void)?
    var onUnstakeAll: (() -> Void)?
    var quoteContext: SubtensorQuoteValidatingContext?
    var analytics: SubtensorValidationReporter?

    var isBatched: Bool {
        netuid != SubtensorPallet.rootNetuid || (plan?.isBatched ?? false)
    }
}

extension SubtensorUnstakeValidatingDependencies {
    var isSubnet: Bool {
        netuid != SubtensorPallet.rootNetuid
    }

    var paysFeeFromPosition: Bool {
        guard
            let transferable = balance?.transferable,
            let networkFee = fee?.amountForCurrentAccount,
            let existentialDeposit else {
            return false
        }

        return !SubtensorAmountPolicy.paysFeeFromFreeBalance(
            transferable: transferable,
            networkFee: networkFee,
            existentialDeposit: existentialDeposit
        )
    }

    var feePayingPosition: Balance? {
        plan?.single.flatMap { positions[$0.hotkey] } ?? positionAlpha
    }

    var sellPlanInputs: [SubtensorSellPlanInput]? {
        guard let plan, !plan.partials.isEmpty else {
            return createSellPlanInput(
                requestedAlpha: amount,
                positionAlpha: positionAlpha,
                hotkey: hotkey
            ).map { [$0] }
        }

        let inputs = plan.partials.compactMap { slice in
            createSellPlanInput(
                requestedAlpha: slice.alpha,
                positionAlpha: positions[slice.hotkey],
                hotkey: slice.hotkey
            )
        }

        return inputs.count == plan.partials.count ? inputs : nil
    }

    var drawsBeyondPreflightHotkey: Bool {
        guard let plan else {
            return false
        }

        return plan.hotkeys != hotkey.map { [$0] }
    }

    var groupHotkeysCoverPlan: Bool {
        guard let groupHotkeys else {
            return false
        }

        return (plan?.hotkeys ?? []).allSatisfy { groupHotkeys[$0] != nil }
    }

    var groupExitHolds: [SubtensorRootHold]? {
        guard !isSubnet, let plan, drawsBeyondPreflightHotkey else {
            return nil
        }

        let unknownHold = SubtensorRootHold(
            interval: preflight?.rootStakeUnlockInterval ?? 0,
            lastStakeBlock: currentBlock.map { UInt64($0) } ?? 0
        )

        return plan.hotkeys.map { holds?[$0] ?? unknownHold }
    }
}

private extension SubtensorUnstakeValidatingDependencies {
    func createSellPlanInput(
        requestedAlpha: Balance?,
        positionAlpha: Balance?,
        hotkey sliceHotkey: AccountId?
    ) -> SubtensorSellPlanInput? {
        guard
            let requestedAlpha,
            let positionAlpha,
            let preflight,
            let bases = sellPlanBases(for: requestedAlpha) else {
            return nil
        }

        return SubtensorSellPlanInput(
            requestedAlpha: requestedAlpha,
            positionAlpha: positionAlpha,
            availability: availability ?? SubtensorPallet.StakeAvailability(available: positionAlpha),
            minimumTaoOut: bases.minimumTaoOut,
            sellLimitPrice: bases.sellLimitPrice,
            isOwnHotkey: owner(of: sliceHotkey, preflight: preflight) == accountId,
            minStake: preflight.minStake,
            nominatorMinStake: preflight.effectiveNominatorMinStake
        )
    }

    func owner(of sliceHotkey: AccountId?, preflight: SubtensorPreflight) -> AccountId? {
        guard let sliceHotkey else {
            return nil
        }

        return groupHotkeys?[sliceHotkey]?.owner ?? (sliceHotkey == hotkey ? preflight.hotkeyOwner : nil)
    }

    func sellPlanBases(for requestedAlpha: Balance) -> (minimumTaoOut: Balance, sellLimitPrice: Balance)? {
        guard isSubnet else {
            let minimumTaoOut = SubtensorAmountPolicy.rootUnstakeAmount(
                requested: requestedAlpha,
                transferable: balance?.transferable,
                networkFee: fee?.amountForCurrentAccount,
                existentialDeposit: existentialDeposit
            )

            return (minimumTaoOut, SubtensorPallet.alphaPriceScale)
        }

        guard
            let latestQuote = quoteContext?.latestQuote,
            let signingLimit = quoteContext?.signingLimit,
            let minimumTaoOut = try? SubtensorTradeQuoteOperationFactory.sellSwapMinimumOut(
                alpha: requestedAlpha,
                feeRate: latestQuote.quote.feeRate,
                limitPrice: signingLimit
            ) else {
            return nil
        }

        return (minimumTaoOut, signingLimit)
    }
}

extension SubtensorValidationFactoryProtocol {
    func validateUnstake(
        for dependencies: SubtensorUnstakeValidatingDependencies,
        locale: Locale,
        onSuccess: @escaping () -> Void
    ) {
        var validations = createUnstakeInputValidations(for: dependencies, locale: locale)

        if let feePayerValidation = createFeePayerValidation(for: dependencies, locale: locale) {
            validations.append(feePayerValidation)
        }

        validations.append(contentsOf: createSellPlanValidations(for: dependencies, locale: locale))

        if !dependencies.isSubnet {
            validations.append(contentsOf: createRootHoldValidations(for: dependencies, locale: locale))
        }

        validations.append(contentsOf: createNetworkStateValidations(for: dependencies.preflight, locale: locale))

        if dependencies.isSubnet {
            validations.append(
                priceImpactAcceptable(quote: dependencies.quoteContext?.latestQuote, locale: locale)
                    .reporting(.priceImpact, to: dependencies.analytics)
            )
            validations.append(
                passesRealtimeQuote(dependencies.quoteContext?.reporting(to: dependencies.analytics), locale: locale)
                    .reportingOutcome(to: dependencies.analytics)
            )
        }

        DataValidationRunner(validators: validations).runValidation(notifyingOnSuccess: onSuccess)
    }
}

private extension SubtensorValidationFactoryProtocol {
    func createUnstakeInputValidations(
        for dependencies: SubtensorUnstakeValidatingDependencies,
        locale: Locale
    ) -> [DataValidating] {
        var validations: [DataValidating] = [
            positionsAreFresh(
                syncFailed: dependencies.syncFailed,
                locale: locale,
                onRetry: { dependencies.onPositionsRefresh() }
            ).reporting(.staleData, to: dependencies.analytics),

            has(
                fee: dependencies.fee,
                locale: locale,
                onError: { dependencies.onFeeRefresh() }
            ).reporting(.feeInProgress, to: dependencies.analytics),

            hasPreflight(
                dependencies.preflight,
                locale: locale,
                onRetry: { dependencies.onPreflightRefresh() }
            )
        ]

        if let onGroupHotkeysRefresh = dependencies.onGroupHotkeysRefresh {
            validations.append(
                groupHotkeysLoaded(dependencies.groupHotkeysCoverPlan, locale: locale, onRetry: onGroupHotkeysRefresh)
            )
        }

        if dependencies.isSubnet {
            validations.append(
                contentsOf: createQuoteValidations(
                    for: dependencies.quoteContext,
                    locale: locale,
                    analytics: dependencies.analytics
                )
            )
        }

        return validations
    }

    func createSellPlanValidations(
        for dependencies: SubtensorUnstakeValidatingDependencies,
        locale: Locale
    ) -> [DataValidating] {
        let inputs: [SubtensorSellPlanInput?] = dependencies.sellPlanInputs ?? [nil]

        return inputs.map { input in
            let validation = sellPlanAllows(
                input,
                assetDisplayInfo: dependencies.assetDisplayInfo,
                onUnstakeAll: dependencies.onUnstakeAll,
                locale: locale
            )

            guard let kind = SubtensorAmountPolicy.analyticsKind(for: input) else {
                return validation
            }

            return validation.reporting(kind, to: dependencies.analytics)
        }
    }

    func createFeePayerValidation(
        for dependencies: SubtensorUnstakeValidatingDependencies,
        locale: Locale
    ) -> DataValidating? {
        if dependencies.isBatched {
            return notViolatingMinBalancePaying(
                fee: dependencies.fee,
                total: dependencies.balance?.transferable,
                minBalance: dependencies.existentialDeposit,
                asset: assetDisplayInfo,
                locale: locale
            ).reporting(.insufficientBalance, to: dependencies.analytics)
        }

        guard dependencies.paysFeeFromPosition else {
            return nil
        }

        return canPayFeeInPlank(
            balance: dependencies.feePayingPosition,
            fee: dependencies.fee,
            asset: assetDisplayInfo,
            locale: locale
        ).reporting(.insufficientBalance, to: dependencies.analytics)
    }

    func createRootHoldValidations(
        for dependencies: SubtensorUnstakeValidatingDependencies,
        locale: Locale
    ) -> [DataValidating] {
        guard let preflight = dependencies.preflight else {
            return []
        }

        guard let groupExitHolds = dependencies.groupExitHolds else {
            return [
                rootUnlockIntervalElapsed(
                    currentBlock: dependencies.currentBlock,
                    lastStakeBlock: preflight.lastStakeBlock,
                    unlockInterval: preflight.rootStakeUnlockInterval,
                    blockTime: preflight.blockTime,
                    locale: locale
                ).reporting(.holdLocked, to: dependencies.analytics)
            ]
        }

        return groupExitHolds.map { hold in
            rootUnlockIntervalElapsed(
                currentBlock: dependencies.currentBlock,
                lastStakeBlock: hold.lastStakeBlock,
                unlockInterval: hold.interval,
                blockTime: preflight.blockTime,
                locale: locale
            ).reporting(.holdLocked, to: dependencies.analytics)
        }
    }
}
