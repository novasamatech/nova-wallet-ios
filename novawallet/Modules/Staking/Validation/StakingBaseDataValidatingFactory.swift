import Foundation_iOS

protocol StakingBaseDataValidatingFactoryProtocol: BaseDataValidatingFactoryProtocol {
    func minStakeNotCrossed(
        for inputAmount: Decimal,
        params: MinStakeCrossedParams,
        chainAsset: ChainAsset,
        locale: Locale
    ) -> DataValidating
}

class StakingBaseDataValidatingFactory: StakingBaseDataValidatingFactoryProtocol {
    weak var view: ControllerBackedProtocol?
    var basePresentable: BaseErrorPresentable { presentable }
    private let presentable: StakingBaseErrorPresentable
    let balanceFactory: BalanceViewModelFactoryProtocol?

    init(
        presentable: StakingBaseErrorPresentable,
        balanceFactory: BalanceViewModelFactoryProtocol?
    ) {
        self.presentable = presentable
        self.balanceFactory = balanceFactory
    }

    func minStakeNotCrossed(
        for inputAmount: Decimal,
        params: MinStakeCrossedParams,
        chainAsset: ChainAsset,
        locale: Locale
    ) -> DataValidating {
        let inputAmountInPlank = inputAmount.toSubstrateAmount(
            precision: chainAsset.assetDisplayInfo.assetPrecision
        ) ?? 0

        let stakedAmountInPlank = params.stakedAmountInPlank
        let minStake = params.minStake

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
                    params.unstakeAllHandler()
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
}
