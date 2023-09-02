import SoraFoundation
import BigInt

struct ExistentialDepositValidationParams {
    let stakingAmount: Decimal?
    let assetBalance: AssetBalance?
    let fee: BigUInt?
    let existentialDeposit: BigUInt?
    let amountUpdateClosure: (Decimal) -> Void
}

protocol NominationPoolDataValidatorFactoryProtocol: BaseDataValidatingFactoryProtocol {
    func nominationPoolHasApy(
        pool: NominationPools.SelectedPool,
        locale: Locale
    ) -> DataValidating

    func selectedPoolIsOpen(
        for pool: NominationPools.PoolStats?,
        locale: Locale
    ) -> DataValidating

    func selectedPoolIsNotFull(
        for pool: NominationPools.PoolStats?,
        maxMembers: UInt32?,
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

    func poolStakingNotViolatingExistentialDeposit(
        for params: ExistentialDepositValidationParams,
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
        pool: NominationPools.SelectedPool,
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
            if let apy = pool.maxApy, apy > 0 {
                return true
            } else {
                return false
            }
        })
    }

    func selectedPoolIsOpen(
        for pool: NominationPools.PoolStats?,
        locale: Locale
    ) -> DataValidating {
        ErrorConditionViolation(onError: { [weak self] in
            guard let view = self?.view else {
                return
            }

            self?.presentable.presentPoolIsNotOpen(from: view, locale: locale)

        }, preservesCondition: {
            pool?.state == .open
        })
    }

    func selectedPoolIsNotFull(
        for pool: NominationPools.PoolStats?,
        maxMembers: UInt32?,
        locale: Locale
    ) -> DataValidating {
        ErrorConditionViolation(onError: { [weak self] in
            guard let view = self?.view else {
                return
            }

            self?.presentable.presentPoolIsFull(from: view, locale: locale)

        }, preservesCondition: {
            guard let pool = pool else {
                return false
            }

            guard let maxMembers = maxMembers else {
                return true
            }

            return pool.membersCount < maxMembers
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

    // swiftlint:disable:next function_body_length
    func poolStakingNotViolatingExistentialDeposit(
        for params: ExistentialDepositValidationParams,
        chainAsset: ChainAsset,
        locale: Locale
    ) -> DataValidating {
        let fee = params.fee ?? 0
        let minBalance = params.existentialDeposit ?? 0
        let feeAndMinBalance = fee + minBalance

        let precision = chainAsset.asset.precision

        return WarningConditionViolation(onWarning: { [weak self] delegate in
            guard
                let view = self?.view,
                let assetBalance = params.assetBalance,
                let balanceFactory = self?.balanceFactory else {
                return
            }

            let maxStake = assetBalance.totalInPlank > feeAndMinBalance ?
                assetBalance.totalInPlank - feeAndMinBalance : 0
            let maxStakeDecimal = maxStake.decimal(precision: precision)
            let maxStakeString = balanceFactory.amountFromValue(
                maxStakeDecimal
            ).value(for: locale)

            let availableBalanceString = balanceFactory.amountFromValue(
                assetBalance.transferable.decimal(precision: precision)
            ).value(for: locale)

            let feeString = balanceFactory.amountFromValue(
                fee.decimal(precision: precision)
            ).value(for: locale)

            let minBalanceString = balanceFactory.amountFromValue(
                minBalance.decimal(precision: precision)
            ).value(for: locale)

            let errorParams = NPoolsEDViolationErrorParams(
                availableBalance: availableBalanceString,
                minimumBalance: minBalanceString,
                fee: feeString,
                maxStake: maxStakeString
            )

            self?.presentable.presentExistentialDepositViolation(
                from: view,
                params: errorParams,
                action: {
                    params.amountUpdateClosure(maxStakeDecimal)
                    delegate.didCompleteWarningHandling()
                }, locale: locale
            )

        }, preservesCondition: {
            guard
                let assetBalance = params.assetBalance,
                let stakingAmountInPlank = params.stakingAmount?.toSubstrateAmount(
                    precision: Int16(bitPattern: precision)
                ) else {
                return true
            }

            return stakingAmountInPlank + fee + minBalance <= assetBalance.totalInPlank
        })
    }
}
