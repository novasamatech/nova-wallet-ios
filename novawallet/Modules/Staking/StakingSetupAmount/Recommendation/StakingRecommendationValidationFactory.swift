import Foundation
import BigInt

struct StakingRecommendationValidationParams {
    let stakingAmount: Decimal?
    let assetBalance: AssetBalance?
    let assetLocks: AssetLocks?
    let fee: BigUInt?
    let existentialDeposit: BigUInt?
    let stakeUpdateClosure: (Decimal) -> Void
}

protocol StakingRecommendationValidationFactoryProtocol: AnyObject {
    func createValidations(
        for params: StakingRecommendationValidationParams,
        controller: ControllerBackedProtocol?,
        balanceViewModelFactory: BalanceViewModelFactoryProtocol,
        presentable: StakingErrorPresentable,
        locale: Locale
    ) -> [DataValidating]
}

final class HybridStakingValidationFactory {
    let directRewardableStake: BigUInt
    let chainAsset: ChainAsset

    init(directRewardableStake: BigUInt, chainAsset: ChainAsset) {
        self.directRewardableStake = directRewardableStake
        self.chainAsset = chainAsset
    }

    private func notStakingLockedInPool(
        params: StakingRecommendationValidationParams,
        controller: ControllerBackedProtocol?,
        balanceViewModelFactory: BalanceViewModelFactoryProtocol,
        presentable: StakingErrorPresentable,
        locale: Locale
    ) -> DataValidating {
        let precision = chainAsset.assetDisplayInfo.assetPrecision
        let rewardableStake = directRewardableStake

        return ErrorConditionViolation(onError: {
            guard let assetBalance = params.assetBalance else {
                return
            }

            let optMaxLock = params.assetLocks?.max { lock1, lock2 in
                lock1.amount < lock2.amount
            }

            let lockReason = optMaxLock?.lockType?.displayType.value(for: locale) ?? ""

            let fee = params.fee ?? 0

            let availableToStake = assetBalance.transferable > fee ? assetBalance.transferable - fee : 0
            let availableToStakeDecimal = availableToStake.decimal(precision: UInt16(bitPattern: precision))

            let availableToStakeString = balanceViewModelFactory.amountFromValue(
                availableToStakeDecimal
            ).value(for: locale)

            let rewardableStakeDecimal = rewardableStake.decimal(precision: UInt16(bitPattern: precision))
            let rewardableStakeString = balanceViewModelFactory.amountFromValue(
                rewardableStakeDecimal
            ).value(for: locale)

            presentable.presentLockedTokensInPoolStaking(
                from: controller,
                lockReason: lockReason,
                availableToStake: availableToStakeString,
                directRewardableToStake: rewardableStakeString,
                locale: locale
            )
        }, preservesCondition: {
            guard
                let assetBalance = params.assetBalance,
                assetBalance.locked > 0,
                let stakingAmountInPlank = params.stakingAmount?.toSubstrateAmount(
                    precision: precision
                ) else {
                return true
            }

            let fee = params.fee ?? 0

            return stakingAmountInPlank + fee <= assetBalance.transferable ||
                stakingAmountInPlank >= rewardableStake
        })
    }
}

extension HybridStakingValidationFactory: StakingRecommendationValidationFactoryProtocol {
    func createValidations(
        for params: StakingRecommendationValidationParams,
        controller: ControllerBackedProtocol?,
        balanceViewModelFactory: BalanceViewModelFactoryProtocol,
        presentable: StakingErrorPresentable,
        locale: Locale
    ) -> [DataValidating] {
        let validation = notStakingLockedInPool(
            params: params,
            controller: controller,
            balanceViewModelFactory: balanceViewModelFactory,
            presentable: presentable,
            locale: locale
        )

        return [validation]
    }
}

final class PoolStakingValidationFactory {
    let chainAsset: ChainAsset

    init(chainAsset: ChainAsset) {
        self.chainAsset = chainAsset
    }

    // swiftlint:disable:next function_body_length
    private func notViolatingExistentialDeposit(
        params: StakingRecommendationValidationParams,
        controller: ControllerBackedProtocol?,
        balanceViewModelFactory: BalanceViewModelFactoryProtocol,
        presentable: StakingErrorPresentable,
        locale: Locale
    ) -> DataValidating {
        let fee = params.fee ?? 0
        let minBalance = params.existentialDeposit ?? 0
        let feeAndMinBalance = fee + minBalance

        let precision = chainAsset.asset.precision

        return WarningConditionViolation(onWarning: { delegate in
            guard
                let view = controller,
                let assetBalance = params.assetBalance else {
                return
            }

            let maxStake = assetBalance.totalInPlank > feeAndMinBalance ?
                assetBalance.totalInPlank - feeAndMinBalance : 0
            let maxStakeDecimal = maxStake.decimal(precision: precision)
            let maxStakeString = balanceViewModelFactory.amountFromValue(
                maxStakeDecimal
            ).value(for: locale)

            let availableBalanceString = balanceViewModelFactory.amountFromValue(
                assetBalance.transferable.decimal(precision: precision)
            ).value(for: locale)

            let feeString = balanceViewModelFactory.amountFromValue(
                fee.decimal(precision: precision)
            ).value(for: locale)

            let minBalanceString = balanceViewModelFactory.amountFromValue(
                minBalance.decimal(precision: precision)
            ).value(for: locale)

            let errorParams = NPoolsEDViolationErrorParams(
                availableBalance: availableBalanceString,
                minimumBalance: minBalanceString,
                fee: feeString,
                maxStake: maxStakeString
            )

            presentable.presentExistentialDepositViolationForPools(
                from: view,
                params: errorParams,
                action: {
                    params.stakeUpdateClosure(maxStakeDecimal)
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

extension PoolStakingValidationFactory: StakingRecommendationValidationFactoryProtocol {
    func createValidations(
        for params: StakingRecommendationValidationParams,
        controller: ControllerBackedProtocol?,
        balanceViewModelFactory: BalanceViewModelFactoryProtocol,
        presentable: StakingErrorPresentable,
        locale: Locale
    ) -> [DataValidating] {
        let validation = notViolatingExistentialDeposit(
            params: params,
            controller: controller,
            balanceViewModelFactory: balanceViewModelFactory,
            presentable: presentable,
            locale: locale
        )

        return [validation]
    }
}

final class DirectStakingValidatorFactory {
    let directRewardableStake: BigUInt?
    let chainAsset: ChainAsset

    init(directRewardableStake: BigUInt?, chainAsset: ChainAsset) {
        self.directRewardableStake = directRewardableStake
        self.chainAsset = chainAsset
    }

    private func notViolatingRewardableStake(
        params: StakingRecommendationValidationParams,
        controller: ControllerBackedProtocol?,
        balanceViewModelFactory: BalanceViewModelFactoryProtocol,
        presentable: StakingErrorPresentable,
        locale: Locale
    ) -> DataValidating {
        let optMinStakeDecimal = directRewardableStake?.decimal(precision: chainAsset.asset.precision)

        return WarningConditionViolation(onWarning: { delegate in
            guard let view = controller else {
                return
            }

            let minStakeString = balanceViewModelFactory.amountFromValue(
                optMinStakeDecimal ?? 0
            ).value(for: locale)

            presentable.presentMinRewardableStakeViolated(
                from: view,
                action: {
                    delegate.didCompleteWarningHandling()
                },
                minStake: minStakeString,
                locale: locale
            )

        }, preservesCondition: {
            guard let minStakeDecimal = optMinStakeDecimal else {
                return true
            }

            let stakingAmount = params.stakingAmount ?? 0

            return stakingAmount >= minStakeDecimal
        })
    }
}

extension DirectStakingValidatorFactory: StakingRecommendationValidationFactoryProtocol {
    func createValidations(
        for params: StakingRecommendationValidationParams,
        controller: ControllerBackedProtocol?,
        balanceViewModelFactory: BalanceViewModelFactoryProtocol,
        presentable: StakingErrorPresentable,
        locale: Locale
    ) -> [DataValidating] {
        let validation = notViolatingRewardableStake(
            params: params,
            controller: controller,
            balanceViewModelFactory: balanceViewModelFactory,
            presentable: presentable,
            locale: locale
        )

        return [validation]
    }
}

final class CombinedStakingValidationFactory: StakingRecommendationValidationFactoryProtocol {
    let factories: [StakingRecommendationValidationFactoryProtocol]

    init(factories: [StakingRecommendationValidationFactoryProtocol]) {
        self.factories = factories
    }

    func createValidations(
        for params: StakingRecommendationValidationParams,
        controller: ControllerBackedProtocol?,
        balanceViewModelFactory: BalanceViewModelFactoryProtocol,
        presentable: StakingErrorPresentable,
        locale: Locale
    ) -> [DataValidating] {
        let validations = factories
            .map { $0.createValidations(
                for: params,
                controller: controller,
                balanceViewModelFactory: balanceViewModelFactory,
                presentable: presentable,
                locale: locale
            ) }
            .flatMap { $0 }

        return validations
    }
}
