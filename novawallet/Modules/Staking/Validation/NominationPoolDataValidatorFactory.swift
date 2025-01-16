import Foundation_iOS
import BigInt

struct ExistentialDepositValidationParams {
    let stakingAmount: Decimal?
    let assetBalance: AssetBalance?
    let fee: ExtrinsicFeeProtocol?
    let existentialDeposit: BigUInt?
    let amountUpdateClosure: (Decimal) -> Void
}

protocol NominationPoolDataValidatorFactoryProtocol: StakingBaseDataValidatingFactoryProtocol {
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

    func canUnstake(
        for inputAmount: Decimal,
        stakedAmountInPlank: BigUInt?,
        chainAsset: ChainAsset,
        locale: Locale
    ) -> DataValidating

    func hasProfitAfterClaim(
        rewards: BigUInt?,
        fee: ExtrinsicFeeProtocol?,
        chainAsset: ChainAsset,
        locale: Locale
    ) -> DataValidating

    func canMigrateIfNeeded(
        needsMigration: Bool?,
        stakingActivity: StakingActivityForValidating,
        onProgress: AsyncValidationOnProgress?,
        locale: Locale
    ) -> DataValidating

    func poolStakingNotViolatingExistentialDeposit(
        for params: ExistentialDepositValidationParams,
        chainAsset: ChainAsset,
        locale: Locale
    ) -> DataValidating

    func nominationPoolIsNotDestroing(
        pool: NominationPools.BondedPool?,
        locale: Locale
    ) -> DataValidating

    func nominationPoolIsNotFullyUnbonding(
        poolMember: NominationPools.PoolMember?,
        locale: Locale
    ) -> DataValidating
}

final class NominationPoolDataValidatorFactory: StakingBaseDataValidatingFactory {
    private let presentable: NominationPoolErrorPresentable

    init(presentable: NominationPoolErrorPresentable, balanceFactory: BalanceViewModelFactoryProtocol) {
        self.presentable = presentable

        super.init(presentable: presentable, balanceFactory: balanceFactory)
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

    func nominationPoolIsNotDestroing(
        pool: NominationPools.BondedPool?,
        locale: Locale
    ) -> DataValidating {
        ErrorConditionViolation(onError: { [weak self] in
            guard let view = self?.view else {
                return
            }

            self?.presentable.presentNominationPoolIsDestroing(
                from: view,
                locale: locale
            )

        }, preservesCondition: {
            guard let pool = pool else {
                return false
            }

            return pool.state != .destroying
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

    func nominationPoolIsNotFullyUnbonding(
        poolMember: NominationPools.PoolMember?,
        locale: Locale
    ) -> DataValidating {
        ErrorConditionViolation(onError: { [weak self] in
            guard let view = self?.view else {
                return
            }
            self?.presentable.presentPoolIsFullyUnbonding(from: view, locale: locale)
        }, preservesCondition: {
            guard let poolMember = poolMember else {
                return false
            }
            return poolMember.points > 0
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
        fee: ExtrinsicFeeProtocol?,
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
            guard let rewards = rewards, let fee = fee?.amount else {
                return false
            }

            return rewards > fee
        })
    }

    func canMigrateIfNeeded(
        needsMigration: Bool?,
        stakingActivity: StakingActivityForValidating,
        onProgress: AsyncValidationOnProgress?,
        locale: Locale
    ) -> DataValidating {
        AsyncErrorConditionViolation(onError: { [weak self] in
            guard let view = self?.view else {
                return
            }

            self?.presentable.presentDirectStakingNotAllowedForMigration(
                from: view,
                locale: locale
            )

        }, preservesCondition: { completion in
            guard let needsMigration else {
                completion(false)
                return
            }

            guard needsMigration else {
                completion(true)
                return
            }

            stakingActivity.hasDirectStaking { result in
                switch result {
                case let .success(hasDirectStaking):
                    completion(!hasDirectStaking)
                case .failure:
                    completion(false)
                }
            }
        }, onProgress: onProgress)
    }

    // swiftlint:disable:next function_body_length
    func poolStakingNotViolatingExistentialDeposit(
        for params: ExistentialDepositValidationParams,
        chainAsset: ChainAsset,
        locale: Locale
    ) -> DataValidating {
        let fee = params.fee?.amountForCurrentAccount ?? 0
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

            let maxStake = assetBalance.balanceCountingEd > feeAndMinBalance ?
                assetBalance.balanceCountingEd - feeAndMinBalance : 0
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

            let action: (() -> Void)?

            if maxStakeDecimal > 0 {
                action = {
                    params.amountUpdateClosure(maxStakeDecimal)
                    delegate.didCompleteWarningHandling()
                }
            } else {
                action = nil
            }

            self?.presentable.presentExistentialDepositViolation(
                from: view,
                params: errorParams,
                action: action,
                locale: locale
            )

        }, preservesCondition: {
            guard
                let assetBalance = params.assetBalance,
                let stakingAmountInPlank = params.stakingAmount?.toSubstrateAmount(
                    precision: Int16(bitPattern: precision)
                ) else {
                return true
            }

            return stakingAmountInPlank + fee + minBalance <= assetBalance.balanceCountingEd
        })
    }
}
