import Foundation

struct SubtensorUnstakeValidatingDep {
    let netuid: UInt16
    let accountId: AccountId
    let hotkey: AccountId?
    let amount: Balance?
    let positionAlpha: Balance?
    let positions: [AccountId: Balance]
    let plan: SubtensorUnstakePlan?
    let groupHotkeys: [AccountId: SubtensorGroupHotkeyInfo]?
    let availability: SubtensorStakingPallet.StakeAvailability?
    let balance: AssetBalance?
    let fee: ExtrinsicFeeProtocol?
    let existentialDeposit: Balance?
    let preflight: SubtensorStakingPreflight?
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

    var isBatched: Bool {
        netuid != SubtensorStakingPallet.rootNetuid || (plan?.isBatched ?? false)
    }
}

extension SubtensorUnstakeValidatingDep {
    var isSubnet: Bool {
        netuid != SubtensorStakingPallet.rootNetuid
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

private extension SubtensorUnstakeValidatingDep {
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
            availability: availability ?? SubtensorStakingPallet.StakeAvailability(available: positionAlpha),
            minimumTaoOut: bases.minimumTaoOut,
            sellLimitPrice: bases.sellLimitPrice,
            isOwnHotkey: owner(of: sliceHotkey, preflight: preflight) == accountId,
            minStake: preflight.minStake,
            nominatorMinStake: preflight.effectiveNominatorMinStake
        )
    }

    func owner(of sliceHotkey: AccountId?, preflight: SubtensorStakingPreflight) -> AccountId? {
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

            return (minimumTaoOut, SubtensorStakingPallet.alphaPriceScale)
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

extension SubtensorStakingValidationFactoryProtocol {
    func validateUnstake(
        for dep: SubtensorUnstakeValidatingDep,
        locale: Locale,
        onSuccess: @escaping () -> Void
    ) {
        var validations = createUnstakeInputValidations(for: dep, locale: locale)

        if let feePayerValidation = createFeePayerValidation(for: dep, locale: locale) {
            validations.append(feePayerValidation)
        }

        validations.append(contentsOf: createSellPlanValidations(for: dep, locale: locale))

        if !dep.isSubnet {
            validations.append(contentsOf: createRootHoldValidations(for: dep, locale: locale))
        }

        validations.append(contentsOf: createNetworkStateValidations(for: dep.preflight, locale: locale))

        if dep.isSubnet {
            validations.append(priceImpactAcceptable(quote: dep.quoteContext?.latestQuote, locale: locale))
            validations.append(passesRealtimeQuote(dep.quoteContext, locale: locale))
        }

        DataValidationRunner(validators: validations).runValidation(notifyingOnSuccess: onSuccess)
    }
}

private extension SubtensorStakingValidationFactoryProtocol {
    func createUnstakeInputValidations(
        for dep: SubtensorUnstakeValidatingDep,
        locale: Locale
    ) -> [DataValidating] {
        var validations: [DataValidating] = [
            positionsAreFresh(
                syncFailed: dep.syncFailed,
                locale: locale,
                onRetry: { dep.onPositionsRefresh() }
            ),

            has(
                fee: dep.fee,
                locale: locale,
                onError: { dep.onFeeRefresh() }
            ),

            hasPreflight(
                dep.preflight,
                locale: locale,
                onRetry: { dep.onPreflightRefresh() }
            )
        ]

        if let onGroupHotkeysRefresh = dep.onGroupHotkeysRefresh {
            validations.append(
                groupHotkeysLoaded(dep.groupHotkeysCoverPlan, locale: locale, onRetry: onGroupHotkeysRefresh)
            )
        }

        if dep.isSubnet {
            validations.append(contentsOf: createQuoteValidations(for: dep.quoteContext, locale: locale))
        }

        return validations
    }

    func createSellPlanValidations(
        for dep: SubtensorUnstakeValidatingDep,
        locale: Locale
    ) -> [DataValidating] {
        let inputs: [SubtensorSellPlanInput?] = dep.sellPlanInputs ?? [nil]

        return inputs.map { input in
            sellPlanAllows(
                input,
                assetDisplayInfo: dep.assetDisplayInfo,
                onUnstakeAll: dep.onUnstakeAll,
                locale: locale
            )
        }
    }

    func createFeePayerValidation(
        for dep: SubtensorUnstakeValidatingDep,
        locale: Locale
    ) -> DataValidating? {
        if dep.isBatched {
            return notViolatingMinBalancePaying(
                fee: dep.fee,
                total: dep.balance?.transferable,
                minBalance: dep.existentialDeposit,
                asset: assetDisplayInfo,
                locale: locale
            )
        }

        guard dep.paysFeeFromPosition else {
            return nil
        }

        return canPayFeeInPlank(
            balance: dep.feePayingPosition,
            fee: dep.fee,
            asset: assetDisplayInfo,
            locale: locale
        )
    }

    func createRootHoldValidations(
        for dep: SubtensorUnstakeValidatingDep,
        locale: Locale
    ) -> [DataValidating] {
        guard let preflight = dep.preflight else {
            return []
        }

        guard let groupExitHolds = dep.groupExitHolds else {
            return [
                rootUnlockIntervalElapsed(
                    currentBlock: dep.currentBlock,
                    lastStakeBlock: preflight.lastStakeBlock,
                    unlockInterval: preflight.rootStakeUnlockInterval,
                    blockTime: preflight.blockTime,
                    locale: locale
                )
            ]
        }

        return groupExitHolds.map { hold in
            rootUnlockIntervalElapsed(
                currentBlock: dep.currentBlock,
                lastStakeBlock: hold.lastStakeBlock,
                unlockInterval: hold.interval,
                blockTime: preflight.blockTime,
                locale: locale
            )
        }
    }
}
