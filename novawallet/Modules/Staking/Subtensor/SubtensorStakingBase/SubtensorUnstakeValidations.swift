import Foundation

struct SubtensorUnstakeValidatingDep {
    let netuid: UInt16
    let accountId: AccountId
    let amount: Balance?
    let positionAlpha: Balance?
    let availability: SubtensorStakingPallet.StakeAvailability?
    let exitHotkeys: [AccountId]?
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
    var onUnstakeAll: (() -> Void)?
    var quoteContext: SubtensorQuoteValidatingContext?

    var isBatched: Bool {
        netuid != SubtensorStakingPallet.rootNetuid || (exitHotkeys?.count ?? 0) > 1
    }
}

extension SubtensorUnstakeValidatingDep {
    var isSubnet: Bool {
        netuid != SubtensorStakingPallet.rootNetuid
    }

    var isRootHoldEnabled: Bool {
        (preflight?.rootStakeUnlockInterval ?? 0) > 0
    }

    var feeNeedsFreeBalance: Bool {
        isBatched || isRootHoldEnabled
    }

    var sellPlanInput: SubtensorSellPlanInput? {
        guard
            let amount,
            let positionAlpha,
            let preflight,
            let bases = sellPlanBases else {
            return nil
        }

        return SubtensorSellPlanInput(
            requestedAlpha: amount,
            positionAlpha: positionAlpha,
            availability: availability ?? SubtensorStakingPallet.StakeAvailability(available: positionAlpha),
            minimumTaoOut: bases.minimumTaoOut,
            sellLimitPrice: bases.sellLimitPrice,
            isOwnHotkey: preflight.hotkeyOwner == accountId,
            minStake: preflight.minStake,
            nominatorMinStake: preflight.effectiveNominatorMinStake
        )
    }

    var groupExitHolds: [SubtensorRootHold]? {
        guard !isSubnet, let exitHotkeys, exitHotkeys.count > 1 else {
            return nil
        }

        let unknownHold = SubtensorRootHold(
            interval: preflight?.rootStakeUnlockInterval ?? 0,
            lastStakeBlock: currentBlock.map { UInt64($0) } ?? 0
        )

        return exitHotkeys.map { holds?[$0] ?? unknownHold }
    }
}

private extension SubtensorUnstakeValidatingDep {
    var sellPlanBases: (minimumTaoOut: Balance, sellLimitPrice: Balance)? {
        guard isSubnet else {
            return amount.map { amount in
                let minimumTaoOut = SubtensorAmountPolicy.rootUnstakeAmount(
                    requested: amount,
                    transferable: balance?.transferable,
                    networkFee: fee?.amountForCurrentAccount,
                    existentialDeposit: existentialDeposit
                )

                return (minimumTaoOut, SubtensorStakingPallet.alphaPriceScale)
            }
        }

        guard
            let latestQuote = quoteContext?.latestQuote,
            let acknowledgedLimit = quoteContext?.acknowledgedLimit,
            let minimumTaoOut = try? SubtensorTradeQuoteFactory.sellSwapMinimumOut(
                alpha: latestQuote.amountIn,
                feeRate: latestQuote.quote.feeRate,
                limitPrice: acknowledgedLimit
            ) else {
            return nil
        }

        return (minimumTaoOut, acknowledgedLimit)
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

        validations.append(
            sellPlanAllows(
                dep.sellPlanInput,
                assetDisplayInfo: dep.assetDisplayInfo,
                onUnstakeAll: dep.onUnstakeAll,
                locale: locale
            )
        )

        if !dep.isSubnet {
            validations.append(contentsOf: createRootHoldValidations(for: dep, locale: locale))
        }

        validations.append(contentsOf: createNetworkStateValidations(for: dep.preflight, locale: locale))

        if dep.isSubnet {
            validations.append(priceImpactAcceptable(quote: dep.quoteContext?.latestQuote, locale: locale))
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

        if dep.isSubnet {
            validations.append(contentsOf: createQuoteValidations(for: dep.quoteContext, locale: locale))
        }

        return validations
    }

    func createFeePayerValidation(
        for dep: SubtensorUnstakeValidatingDep,
        locale: Locale
    ) -> DataValidating? {
        guard dep.feeNeedsFreeBalance else {
            return nil
        }

        return canPayBatchedNetworkFee(
            transferable: dep.balance?.transferable,
            networkFee: dep.fee?.amountForCurrentAccount,
            existentialDeposit: dep.existentialDeposit,
            locale: locale
        )
    }

    func createRootHoldValidations(
        for dep: SubtensorUnstakeValidatingDep,
        locale: Locale
    ) -> [DataValidating] {
        guard let groupExitHolds = dep.groupExitHolds else {
            return [
                rootUnlockIntervalElapsed(
                    currentBlock: dep.currentBlock,
                    lastStakeBlock: dep.preflight?.lastStakeBlock,
                    unlockInterval: dep.preflight?.rootStakeUnlockInterval,
                    locale: locale
                )
            ]
        }

        return groupExitHolds.map { hold in
            rootUnlockIntervalElapsed(
                currentBlock: dep.currentBlock,
                lastStakeBlock: hold.lastStakeBlock,
                unlockInterval: hold.interval,
                locale: locale
            )
        }
    }
}
