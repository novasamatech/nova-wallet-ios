import SoraFoundation
import BigInt

protocol NominationPoolDataValidatorFactoryProtocol: BaseDataValidatingFactoryProtocol {
    func nominationPoolHasApy(
        method: StakingSelectionMethod,
        locale: Locale
    ) -> DataValidating

    func hasPoolMemberUnstakeSpace(
        for poolMember: NominationPools.PoolMember?,
        limits: NominationPools.UnstakeLimits?,
        eraCountdown: EraCountdownDisplayProtocol?,
        locale: Locale
    ) -> DataValidating

    func hasLedgerUnstakeSpace(
        for ledger: StakingLedger?,
        limits: NominationPools.UnstakeLimits?,
        eraCountdown: EraCountdownDisplayProtocol?,
        locale: Locale
    ) -> DataValidating

    func minStakeNotCrossed(
        for inputAmount: Decimal,
        stakedAmountInPlank: BigUInt?,
        minStake: BigUInt?,
        chainAsset: ChainAsset,
        locale: Locale
    ) -> DataValidating

    func canUnstake(
        for inputAmount: Decimal,
        stakedAmountInPlank: BigUInt?,
        chainAsset: ChainAsset,
        locale: Locale
    ) -> DataValidating

    func hasProfitAfterClaim(
        rewards: BigUInt?,
        fee: BigUInt?,
        chainAsset: ChainAsset,
        locale: Locale
    ) -> DataValidating
}

final class NominationPoolDataValidatorFactory {
    weak var view: (ControllerBackedProtocol & Localizable)?
    let presentable: NominationPoolErrorPresentable
    var basePresentable: BaseErrorPresentable { presentable }

    let balanceFactory: BalanceViewModelFactoryProtocol

    init(presentable: NominationPoolErrorPresentable, balanceFactory: BalanceViewModelFactoryProtocol) {
        self.presentable = presentable
        self.balanceFactory = balanceFactory
    }
}

extension NominationPoolDataValidatorFactory: NominationPoolDataValidatorFactoryProtocol {
    func nominationPoolHasApy(
        method: StakingSelectionMethod,
        locale: Locale
    ) -> DataValidating {
        WarningConditionViolation(onWarning: { [weak self] delegate in
            guard let view = self?.view else {
                return
            }
            self?.presentable.presentNominationPoolHasNoApy(
                from: view,
                action: {
                    delegate.didCompleteWarningHandling()
                },
                locale: locale
            )
        }, preservesCondition: {
            guard case let .pool(selectedPool) = method.selectedStakingOption else {
                return true
            }

            if let apy = selectedPool.maxApy, apy > 0 {
                return true
            } else {
                return false
            }
        })
    }

    func hasPoolMemberUnstakeSpace(
        for poolMember: NominationPools.PoolMember?,
        limits: NominationPools.UnstakeLimits?,
        eraCountdown: EraCountdownDisplayProtocol?,
        locale: Locale
    ) -> DataValidating {
        ErrorConditionViolation(onError: { [weak self] in
            let minRedeemEra = (poolMember?.unbondingEras ?? []).min { $0.key.value < $1.key.value }

            let timeInteraval: TimeInterval? = minRedeemEra.flatMap {
                eraCountdown?.timeIntervalTillStart(targetEra: $0.key.value)
            }

            let timeString = timeInteraval?.localizedDaysHours(for: locale) ?? ""

            self?.presentable.presentNoUnstakeSpace(
                from: self?.view,
                unstakeAfter: timeString,
                locale: locale
            )

        }, preservesCondition: {
            guard
                let poolMember = poolMember,
                let limits = limits,
                let eraCountdown = eraCountdown else {
                return false
            }

            let targetEra = eraCountdown.activeEra + limits.bondingDuration

            let hasSpace = poolMember.unbondingEras.count < limits.poolMemberMaxUnlockings
            let hasEraUnstaking = poolMember.unbondingEras.contains { $0.key.value == targetEra }

            return hasSpace || hasEraUnstaking
        })
    }

    func hasLedgerUnstakeSpace(
        for stakingLedger: StakingLedger?,
        limits: NominationPools.UnstakeLimits?,
        eraCountdown: EraCountdownDisplayProtocol?,
        locale: Locale
    ) -> DataValidating {
        ErrorConditionViolation(onError: { [weak self] in
            let minRedeemEra = (stakingLedger?.unlocking ?? []).min { $0.era < $1.era }

            let timeInteraval: TimeInterval? = minRedeemEra.flatMap {
                eraCountdown?.timeIntervalTillStart(targetEra: $0.era)
            }
            let timeString = timeInteraval?.localizedDaysHours(for: locale) ?? ""

            self?.presentable.presentNoUnstakeSpace(
                from: self?.view,
                unstakeAfter: timeString,
                locale: locale
            )

        }, preservesCondition: {
            guard
                let stakingLedger = stakingLedger,
                let limits = limits,
                let eraCountdown = eraCountdown else {
                return false
            }

            let hasSpace = stakingLedger.unlocking.count < limits.globalMaxUnlockings
            let hasRedeemable = stakingLedger.redeemable(inEra: eraCountdown.activeEra) > 0

            return hasSpace || hasRedeemable
        })
    }

    func minStakeNotCrossed(
        for inputAmount: Decimal,
        stakedAmountInPlank: BigUInt?,
        minStake: BigUInt?,
        chainAsset: ChainAsset,
        locale: Locale
    ) -> DataValidating {
        let inputAmountInPlank = inputAmount.toSubstrateAmount(
            precision: chainAsset.assetDisplayInfo.assetPrecision
        ) ?? 0

        return WarningConditionViolation(onWarning: { [weak self] delegate in
            guard let balanceFactory = self?.balanceFactory else {
                return
            }

            let stakedAmount = stakedAmountInPlank ?? 0
            let diff = stakedAmount >= inputAmountInPlank ? stakedAmount - inputAmountInPlank : 0

            let minStakeDecimal = (minStake ?? 0).decimal(precision: chainAsset.asset.precision)
            let diffDecimal = diff.decimal(precision: chainAsset.asset.precision)

            let minStakeString = balanceFactory.amountFromValue(minStakeDecimal).value(for: locale)
            let diffString = balanceFactory.amountFromValue(diffDecimal).value(for: locale)

            self?.presentable.presentCrossedMinStake(
                from: self?.view,
                minStake: minStakeString,
                remaining: diffString,
                action: {
                    delegate.didCompleteWarningHandling()
                },
                locale: locale
            )

        }, preservesCondition: {
            guard
                let stakedAmountInPlank = stakedAmountInPlank,
                let minStake = minStake,
                stakedAmountInPlank >= inputAmountInPlank else {
                return false
            }

            let diff = stakedAmountInPlank - inputAmountInPlank

            return diff == 0 || diff >= minStake
        })
    }

    func canUnstake(
        for inputAmount: Decimal,
        stakedAmountInPlank: BigUInt?,
        chainAsset: ChainAsset,
        locale: Locale
    ) -> DataValidating {
        let inputAmountInPlank = inputAmount.toSubstrateAmount(
            precision: chainAsset.assetDisplayInfo.assetPrecision
        ) ?? 0

        return ErrorConditionViolation(onError: { [weak self] in
            guard let view = self?.view else {
                return
            }

            self?.presentable.presentUnstakeAmountToHigh(from: view, locale: locale)

        }, preservesCondition: {
            inputAmountInPlank > 0 && inputAmountInPlank <= (stakedAmountInPlank ?? 0)
        })
    }

    func hasProfitAfterClaim(
        rewards: BigUInt?,
        fee: BigUInt?,
        chainAsset _: ChainAsset,
        locale: Locale
    ) -> DataValidating {
        WarningConditionViolation(onWarning: { [weak self] delegate in
            guard let view = self?.view else {
                return
            }

            self?.presentable.presentNoProfitAfterClaimRewards(
                from: view,
                action: {
                    delegate.didCompleteWarningHandling()
                },
                locale: locale
            )
        }, preservesCondition: {
            guard let rewards = rewards, let fee = fee else {
                return false
            }

            return rewards > fee
        })
    }
}
