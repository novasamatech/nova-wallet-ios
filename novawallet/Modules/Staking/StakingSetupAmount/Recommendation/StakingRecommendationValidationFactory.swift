import Foundation
import BigInt

struct StakingRecommendationValidationParams {
    let stakingAmount: Decimal?
    let assetBalance: AssetBalance?
    let assetLocks: AssetLocks?
    let fee: ExtrinsicFeeProtocol?
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

            let fee = params.fee?.amountForCurrentAccount ?? 0

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

            let fee = params.fee?.amountForCurrentAccount ?? 0

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
