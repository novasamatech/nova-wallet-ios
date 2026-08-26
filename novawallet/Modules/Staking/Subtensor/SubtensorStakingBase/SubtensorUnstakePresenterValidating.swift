import Foundation

struct SubtensorUnstakeValidatingDep {
    let netuid: UInt16
    let amount: Balance?
    let stakedAmount: Balance?
    let isFullUnstake: Bool
    let balance: AssetBalance?
    let fee: ExtrinsicFeeProtocol?
    let preflight: SubtensorStakingPreflight?
    let claimablePayout: Balance?
    let currentBlock: BlockNumber?
    let blockTime: BlockTime
    let assetDisplayInfo: AssetBalanceDisplayInfo
    let onFeeRefresh: () -> Void
    let onPreflightRefresh: () -> Void
    /// nil where the amount is already committed, which drops the offer to close the position
    var onUnstakeAll: (() -> Void)?
    var quoteContext: SubtensorQuoteValidatingContext?
    /// spec §3.2 — the staked amount below is the last value the resync managed to read, so a
    /// failed resync has to block rather than let it become the basis of an extrinsic
    var positionsSyncFailed = false
    var onPositionsRefresh: (() -> Void)?

    var availableToUnstake: Balance? {
        guard let stakedAmount, let preflight else {
            return nil
        }

        return SubtensorUnstakeBasis.make(
            staked: stakedAmount,
            availability: preflight.stakeAvailability
        ).available
    }

    var remainder: Balance? {
        guard !isFullUnstake, let stakedAmount, let amount else {
            return 0
        }

        return stakedAmount >= amount ? stakedAmount - amount : 0
    }

    /// the chain's min-out check runs on TAO, so an alpha amount only counts through
    /// the simulated receive; root amounts are already TAO
    var quotedTaoOut: Balance? {
        guard quoteContext != nil else {
            return amount
        }

        return quoteContext?.quote?.expectedOut
    }

    var isRootFlow: Bool {
        netuid == SubtensorStakingPallet.rootNetuid
    }

    var remainderTaoValue: Balance? {
        guard let remainder else {
            return nil
        }

        guard let spot = quoteContext?.quote?.spotPrice else {
            return quoteContext == nil ? remainder : nil
        }

        return remainder * spot / SubtensorStakingPallet.alphaPriceScale
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
        var validations: [DataValidating] = [
            dataValidationFactory.positionsAreFresh(
                syncFailed: dep.positionsSyncFailed,
                locale: selectedLocale,
                onRetry: { dep.onPositionsRefresh?() }
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

        if let quoteContext = dep.quoteContext {
            validations.append(
                dataValidationFactory.hasFreshQuote(
                    quoteContext.quote,
                    for: quoteContext.args,
                    locale: selectedLocale,
                    onRetry: { quoteContext.onQuoteRefresh() }
                )
            )

            validations.append(
                dataValidationFactory.orderWithinSlippageTolerance(
                    quote: quoteContext.quote,
                    limitPrice: quoteContext.limitPrice,
                    locale: selectedLocale
                )
            )
        }

        validations.append(contentsOf: [
            dataValidationFactory.canPayFeeFromStakeOtherwiseWarns(
                transferable: dep.balance?.transferable,
                fee: dep.fee?.amountForCurrentAccount,
                locale: selectedLocale
            ),

            dataValidationFactory.unstakeNotExceedsAvailable(
                amount: dep.isFullUnstake ? dep.stakedAmount : dep.amount,
                available: dep.availableToUnstake,
                assetDisplayInfo: dep.assetDisplayInfo,
                locale: selectedLocale
            ),

            dataValidationFactory.unstakeAboveMinTaoOut(
                taoOut: dep.quotedTaoOut,
                minAmount: dep.preflight?.minStake,
                isFullUnstake: dep.isFullUnstake,
                locale: selectedLocale
            ),

            dataValidationFactory.remainderNotBelowNominatorMin(
                remainder: dep.remainderTaoValue,
                nominatorMinStake: dep.preflight?.effectiveNominatorMinStake,
                onUnstakeAll: dep.onUnstakeAll,
                locale: selectedLocale
            )
        ])

        // the chain applies the unlock hold only when `netuid.is_root()`, and only root
        // operations write the age it is measured against, so a subnet unstake must not
        // inherit a hold left behind by a root stake or claim on the same hotkey
        if dep.isRootFlow {
            validations.append(
                dataValidationFactory.rootUnlockIntervalElapsed(
                    currentBlock: dep.currentBlock,
                    lastStakeBlock: dep.preflight?.lastStakeBlock,
                    unlockInterval: dep.preflight?.rootStakeUnlockInterval,
                    blockTime: dep.blockTime,
                    locale: selectedLocale
                )
            )
        }

        validations.append(contentsOf: [
            dataValidationFactory.claimFirstAdvisory(
                claimable: dep.claimablePayout,
                threshold: dep.preflight?.rootClaimableThreshold,
                locale: selectedLocale
            ),

            dataValidationFactory.noColdkeySwapInProgress(
                hasAnnouncement: dep.preflight?.hasColdkeySwapAnnouncement,
                locale: selectedLocale
            ),

            dataValidationFactory.safeModeInactive(
                safeModeActive: dep.preflight?.isSafeModeActive,
                locale: selectedLocale
            )
        ])

        // the impact warning runs after every hard error rule so a blocked submission
        // is never preceded by a proceed-anyway prompt
        if let quoteContext = dep.quoteContext {
            validations.append(
                dataValidationFactory.priceImpactAcceptable(
                    quote: quoteContext.quote,
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
