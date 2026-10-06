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
    let blockTime: BlockTime
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
            availability: availability ?? SubtensorStakingPallet.StakeAvailability(
                total: positionAlpha,
                locked: 0,
                available: positionAlpha
            ),
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
            return amount.map { ($0, SubtensorStakingPallet.alphaPriceScale) }
        }

        guard
            let latestQuote = quoteContext?.latestQuote,
            let acknowledgedLimit = quoteContext?.acknowledgedLimit else {
            return nil
        }

        return (latestQuote.swapMinimumOut, acknowledgedLimit)
    }
}

protocol SubtensorUnstakePresenterValidating {
    func createUnstakeValidations(
        for dep: SubtensorUnstakeValidatingDep,
        dataValidationFactory: SubtensorStakingValidationFactoryProtocol,
        selectedLocale: Locale
    ) -> [DataValidating]
}

extension SubtensorUnstakePresenterValidating {
    func createUnstakeValidations(
        for dep: SubtensorUnstakeValidatingDep,
        dataValidationFactory: SubtensorStakingValidationFactoryProtocol,
        selectedLocale: Locale
    ) -> [DataValidating] {
        var validations = createUnstakeInputValidations(
            for: dep,
            dataValidationFactory: dataValidationFactory,
            selectedLocale: selectedLocale
        )

        validations.append(
            createFeePayerValidation(
                for: dep,
                dataValidationFactory: dataValidationFactory,
                selectedLocale: selectedLocale
            )
        )

        validations.append(
            dataValidationFactory.sellPlanAllows(
                dep.sellPlanInput,
                assetDisplayInfo: dep.assetDisplayInfo,
                onUnstakeAll: dep.onUnstakeAll,
                locale: selectedLocale
            )
        )

        if !dep.isSubnet {
            validations.append(
                contentsOf: createRootHoldValidations(
                    for: dep,
                    dataValidationFactory: dataValidationFactory,
                    selectedLocale: selectedLocale
                )
            )
        }

        validations.append(
            contentsOf: SubtensorCommonValidations.createNetworkStateValidations(
                for: dep.preflight,
                dataValidationFactory: dataValidationFactory,
                locale: selectedLocale
            )
        )

        if dep.isSubnet {
            validations.append(
                dataValidationFactory.priceImpactAcceptable(
                    quote: dep.quoteContext?.latestQuote,
                    locale: selectedLocale
                )
            )
        }

        return validations
    }

    func validateUnstake(
        for dep: SubtensorUnstakeValidatingDep,
        dataValidationFactory: SubtensorStakingValidationFactoryProtocol,
        selectedLocale: Locale,
        onSuccess: @escaping () -> Void
    ) {
        let validations = createUnstakeValidations(
            for: dep,
            dataValidationFactory: dataValidationFactory,
            selectedLocale: selectedLocale
        )

        DataValidationRunner(validators: validations).runValidation(notifyingOnSuccess: onSuccess)
    }
}

private extension SubtensorUnstakePresenterValidating {
    func createUnstakeInputValidations(
        for dep: SubtensorUnstakeValidatingDep,
        dataValidationFactory: SubtensorStakingValidationFactoryProtocol,
        selectedLocale: Locale
    ) -> [DataValidating] {
        var validations: [DataValidating] = [
            dataValidationFactory.positionsAreFresh(
                syncFailed: dep.syncFailed,
                locale: selectedLocale,
                onRetry: { dep.onPositionsRefresh() }
            ),

            dataValidationFactory.has(
                fee: dep.fee,
                locale: selectedLocale,
                onError: { dep.onFeeRefresh() }
            ),

            dataValidationFactory.hasPreflight(
                dep.preflight,
                locale: selectedLocale,
                onRetry: { dep.onPreflightRefresh() }
            )
        ]

        if dep.isSubnet {
            validations.append(
                contentsOf: SubtensorCommonValidations.createQuoteValidations(
                    for: dep.quoteContext,
                    dataValidationFactory: dataValidationFactory,
                    locale: selectedLocale
                )
            )
        }

        return validations
    }

    func createFeePayerValidation(
        for dep: SubtensorUnstakeValidatingDep,
        dataValidationFactory: SubtensorStakingValidationFactoryProtocol,
        selectedLocale: Locale
    ) -> DataValidating {
        guard dep.isBatched || dep.isRootHoldEnabled else {
            return dataValidationFactory.canPayFeeFromStakeOtherwiseWarns(
                transferable: dep.balance?.transferable,
                fee: dep.fee?.amountForCurrentAccount,
                existentialDeposit: dep.existentialDeposit,
                locale: selectedLocale
            )
        }

        return dataValidationFactory.canPayBatchedNetworkFee(
            transferable: dep.balance?.transferable,
            networkFee: dep.fee?.amountForCurrentAccount,
            existentialDeposit: dep.existentialDeposit,
            locale: selectedLocale
        )
    }

    func createRootHoldValidations(
        for dep: SubtensorUnstakeValidatingDep,
        dataValidationFactory: SubtensorStakingValidationFactoryProtocol,
        selectedLocale: Locale
    ) -> [DataValidating] {
        guard let groupExitHolds = dep.groupExitHolds else {
            return [
                dataValidationFactory.rootUnlockIntervalElapsed(
                    currentBlock: dep.currentBlock,
                    lastStakeBlock: dep.preflight?.lastStakeBlock,
                    unlockInterval: dep.preflight?.rootStakeUnlockInterval,
                    blockTime: dep.blockTime,
                    locale: selectedLocale
                )
            ]
        }

        return groupExitHolds.map { hold in
            dataValidationFactory.rootUnlockIntervalElapsed(
                currentBlock: dep.currentBlock,
                lastStakeBlock: hold.lastStakeBlock,
                unlockInterval: hold.interval,
                blockTime: dep.blockTime,
                locale: selectedLocale
            )
        }
    }
}
