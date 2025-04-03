import Foundation
import BigInt
import Foundation_iOS

typealias RelaychainStakingErrorPresentable = StakingErrorPresentable & NominationPoolErrorPresentable

struct RelaychainStakingValidationParams {
    let chainAsset: ChainAsset
    let stakingAmount: Decimal?
    let availableBalance: BigUInt?
    let assetBalance: AssetBalance?
    let fee: ExtrinsicFeeProtocol?
    let existentialDeposit: BigUInt?
    let feeRefreshClosure: () -> Void
    let stakeUpdateClosure: (Decimal) -> Void
}

protocol RelaychainStakingValidatorFacadeProtocol {
    func createValidations(
        from stakingMethod: StakingSelectionMethod,
        params: RelaychainStakingValidationParams,
        locale: Locale
    ) -> [DataValidating]
}

final class RelaychainStakingValidatorFacade {
    let directStakingValidatingFactory: StakingDataValidatingFactory
    let poolStakingValidatingFactory: NominationPoolDataValidatorFactory

    var view: ControllerBackedProtocol? {
        get {
            directStakingValidatingFactory.view
        }

        set {
            directStakingValidatingFactory.view = newValue
            poolStakingValidatingFactory.view = newValue
        }
    }

    init(
        presentable: RelaychainStakingErrorPresentable,
        balanceFactory: BalanceViewModelFactoryProtocol
    ) {
        directStakingValidatingFactory = StakingDataValidatingFactory(
            presentable: presentable,
            balanceFactory: balanceFactory
        )

        poolStakingValidatingFactory = NominationPoolDataValidatorFactory(
            presentable: presentable,
            balanceFactory: balanceFactory
        )
    }

    private func createCommonValidations(
        params: RelaychainStakingValidationParams,
        restrictions: RelaychainStakingRestrictions?,
        staking: SelectedStakingOption?,
        locale: Locale
    ) -> [DataValidating] {
        let assetDisplayInfo = params.chainAsset.assetDisplayInfo

        return [
            directStakingValidatingFactory.has(
                fee: params.fee,
                locale: locale
            ) {
                params.feeRefreshClosure()
            },
            directStakingValidatingFactory.canSpendAmountInPlank(
                balance: params.availableBalance,
                spendingAmount: params.stakingAmount,
                asset: assetDisplayInfo,
                locale: locale
            ),
            directStakingValidatingFactory.canPayFeeInPlank(
                balance: params.assetBalance?.transferable,
                fee: params.fee,
                asset: assetDisplayInfo,
                locale: locale
            ),
            directStakingValidatingFactory.canPayFeeSpendingAmountInPlank(
                balance: params.availableBalance,
                fee: params.fee,
                spendingAmount: params.stakingAmount,
                asset: assetDisplayInfo,
                locale: locale
            ),
            directStakingValidatingFactory.allowsNewNominators(
                flag: restrictions?.allowsNewStakers ?? false,
                staking: staking,
                locale: locale
            ),
            directStakingValidatingFactory.canNominateInPlank(
                amount: params.stakingAmount,
                minimalBalance: restrictions?.minJoinStake,
                minNominatorBond: restrictions?.minJoinStake,
                precision: params.chainAsset.asset.precision,
                locale: locale
            )
        ]
    }

    private func createPoolValidations(
        for selectedPool: NominationPools.SelectedPool,
        params: RelaychainStakingValidationParams,
        locale: Locale
    ) -> [DataValidating] {
        [
            poolStakingValidatingFactory.nominationPoolHasApy(pool: selectedPool, locale: locale),
            poolStakingValidatingFactory.poolStakingNotViolatingExistentialDeposit(
                for: .init(
                    stakingAmount: params.stakingAmount,
                    assetBalance: params.assetBalance,
                    fee: params.fee,
                    existentialDeposit: params.existentialDeposit,
                    amountUpdateClosure: params.stakeUpdateClosure
                ),
                chainAsset: params.chainAsset,
                locale: locale
            )
        ]
    }

    private func createDirectStakingValidations(
        for restrictions: RelaychainStakingRestrictions?,
        params: RelaychainStakingValidationParams,
        locale: Locale
    ) -> [DataValidating] {
        [
            directStakingValidatingFactory.minRewardableStakeIsNotViolated(
                amount: params.stakingAmount,
                rewardableStake: restrictions?.minRewardableStake,
                assetInfo: params.chainAsset.assetDisplayInfo,
                locale: locale
            )
        ]
    }

    private func createValidationsForRecommendation(
        _ recommendation: RelaychainStakingRecommendation,
        params: RelaychainStakingValidationParams,
        locale: Locale
    ) -> [DataValidating] {
        switch recommendation.staking {
        case let .pool(selectedPool):
            return createPoolValidations(for: selectedPool, params: params, locale: locale)
        case .direct:
            return createDirectStakingValidations(
                for: recommendation.restrictions,
                params: params,
                locale: locale
            )
        }
    }

    private func createValidationsForManual(
        _ manual: RelaychainStakingManual,
        params: RelaychainStakingValidationParams,
        locale: Locale
    ) -> [DataValidating] {
        switch manual.staking {
        case let .pool(pool):
            return createPoolValidations(for: pool, params: params, locale: locale)
        case .direct:
            return createDirectStakingValidations(
                for: manual.restrictions,
                params: params,
                locale: locale
            )
        }
    }
}

extension RelaychainStakingValidatorFacade: RelaychainStakingValidatorFacadeProtocol {
    func createValidations(
        from stakingMethod: StakingSelectionMethod,
        params: RelaychainStakingValidationParams,
        locale: Locale
    ) -> [DataValidating] {
        let commonValidations = createCommonValidations(
            params: params,
            restrictions: stakingMethod.restrictions,
            staking: stakingMethod.selectedStakingOption,
            locale: locale
        )

        switch stakingMethod {
        case let .recommendation(optRecommendation):
            guard let recommendation = optRecommendation else {
                return commonValidations
            }

            let specificValidations = createValidationsForRecommendation(
                recommendation,
                params: params,
                locale: locale
            )

            return commonValidations + specificValidations
        case let .manual(manual):
            let specificValidations = createValidationsForManual(
                manual,
                params: params,
                locale: locale
            )

            return commonValidations + specificValidations
        }
    }
}
