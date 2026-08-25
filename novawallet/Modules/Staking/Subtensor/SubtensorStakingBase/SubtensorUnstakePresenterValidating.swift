import Foundation

struct SubtensorUnstakeValidatingDep {
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

    var availableToUnstake: Balance? {
        guard let stakedAmount else {
            return nil
        }

        guard let availability = preflight?.stakeAvailability else {
            return preflight != nil ? stakedAmount : nil
        }

        return min(stakedAmount, availability.available)
    }

    var remainder: Balance? {
        guard !isFullUnstake, let stakedAmount, let amount else {
            return 0
        }

        return stakedAmount >= amount ? stakedAmount - amount : 0
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
        [
            dataValidationFactory.has(
                fee: dep.fee,
                locale: selectedLocale,
                onError: { dep.onFeeRefresh() }
            ),

            dataValidationFactory.hasPreflight(
                dep.preflight,
                locale: selectedLocale,
                onRetry: { dep.onPreflightRefresh() }
            ),

            dataValidationFactory.canPayFeeFromStakeOtherwiseWarns(
                transferable: dep.balance?.transferable,
                fee: dep.fee?.amountForCurrentAccount,
                locale: selectedLocale
            ),

            dataValidationFactory.unstakeNotExceedsAvailable(
                amount: dep.isFullUnstake ? dep.stakedAmount : dep.amount,
                available: dep.availableToUnstake,
                locale: selectedLocale
            ),

            dataValidationFactory.unstakeAboveMinTaoOut(
                taoOut: dep.amount,
                minAmount: dep.preflight?.minStake,
                isFullUnstake: dep.isFullUnstake,
                locale: selectedLocale
            ),

            dataValidationFactory.remainderNotBelowNominatorMin(
                remainder: dep.remainder,
                nominatorMinStake: dep.preflight?.effectiveNominatorMinStake,
                locale: selectedLocale
            ),

            dataValidationFactory.rootUnlockIntervalElapsed(
                currentBlock: dep.currentBlock,
                lastStakeBlock: dep.preflight?.lastStakeBlock,
                unlockInterval: dep.preflight?.rootStakeUnlockInterval,
                blockTime: dep.blockTime,
                locale: selectedLocale
            ),

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
        ]
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
