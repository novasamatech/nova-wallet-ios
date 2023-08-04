import Foundation
import SoraFoundation
import BigInt

protocol StakingAmountViewModelFactoryProtocol {
    func earnupModel(
        earnings: Decimal?,
        chainAsset: ChainAsset,
        locale: Locale
    ) -> TitleHorizontalMultiValueView.Model

    func balance(amount: BigUInt?, chainAsset: ChainAsset, locale: Locale) -> TitleHorizontalMultiValueView.Model

    func stakingTypeViewModel(stakingType: SelectedStakingOption) -> StakingTypeViewModel
}

struct StakingAmountViewModelFactory: StakingAmountViewModelFactoryProtocol {
    let balanceViewModelFactory: BalanceViewModelFactoryProtocol
    let estimatedEarningsFormatter: LocalizableResource<NumberFormatter>

    init(
        balanceViewModelFactory: BalanceViewModelFactoryProtocol,
        estimatedEarningsFormatter: LocalizableResource<NumberFormatter>
    ) {
        self.balanceViewModelFactory = balanceViewModelFactory
        self.estimatedEarningsFormatter = estimatedEarningsFormatter
    }

    func earnupModel(
        earnings: Decimal?,
        chainAsset _: ChainAsset,
        locale: Locale
    ) -> TitleHorizontalMultiValueView.Model {
        let amount = earnings.map { estimatedEarningsFormatter.value(for: locale).stringFromDecimal($0) } ?? ""
        return .init(
            title: "Estimated rewards",
            subtitle: amount ?? "",
            value: "/ year"
        )
    }

    func balance(
        amount: BigUInt?,
        chainAsset: ChainAsset,
        locale: Locale
    ) -> TitleHorizontalMultiValueView.Model {
        let balance = balanceViewModelFactory.balanceWithPriceIfPossible(
            amount: amount,
            priceData: nil,
            chainAsset: chainAsset
        ).value(for: locale)

        let title = R.string.localizable.walletSendAmountTitle(preferredLanguages: locale.rLanguages)
        let available = R.string.localizable.commonAvailablePrefix(preferredLanguages: locale.rLanguages)
        return .init(
            title: title,
            subtitle: available,
            value: balance.amount
        )
    }

    func stakingTypeViewModel(stakingType: SelectedStakingOption) -> StakingTypeViewModel {
        switch stakingType {
        case .direct:
            return StakingTypeViewModel(
                title: "Direct staking",
                subtitle: "Recommended",
                isRecommended: true
            )
        case .pool:
            return StakingTypeViewModel(
                title: "Pool staking",
                subtitle: "Recommended",
                isRecommended: true
            )
        }
    }
}
