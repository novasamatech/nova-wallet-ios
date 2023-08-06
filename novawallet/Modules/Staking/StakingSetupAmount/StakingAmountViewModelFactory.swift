import Foundation
import SoraFoundation
import BigInt

protocol StakingAmountViewModelFactoryProtocol {
    func earnupModel(
        earnings: Decimal?,
        locale: Locale
    ) -> TitleHorizontalMultiValueView.Model

    func balance(amount: BigUInt?, chainAsset: ChainAsset, locale: Locale) -> TitleHorizontalMultiValueView.Model

    func recommendedStakingTypeViewModel(
        for stakingType: SelectedStakingOption,
        locale: Locale
    ) -> StakingTypeViewModel
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
        locale: Locale
    ) -> TitleHorizontalMultiValueView.Model {
        let amount = earnings.map { estimatedEarningsFormatter.value(for: locale).stringFromDecimal($0) } ?? ""
        return .init(
            title: R.string.localizable.stakingEstimatedEarnings(preferredLanguages: locale.rLanguages),
            subtitle: amount ?? "",
            value: R.string.localizable.commonPerYear(preferredLanguages: locale.rLanguages)
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

    func recommendedStakingTypeViewModel(
        for stakingType: SelectedStakingOption,
        locale: Locale
    ) -> StakingTypeViewModel {
        switch stakingType {
        case .direct:
            return StakingTypeViewModel(
                icon: nil,
                title: R.string.localizable.stakingDirectStaking(preferredLanguages: locale.rLanguages),
                subtitle: R.string.localizable.commonRecommended(preferredLanguages: locale.rLanguages),
                isRecommended: true
            )
        case .pool:
            return StakingTypeViewModel(
                icon: nil,
                title: R.string.localizable.stakingPoolStaking(preferredLanguages: locale.rLanguages),
                subtitle: R.string.localizable.commonRecommended(preferredLanguages: locale.rLanguages),
                isRecommended: true
            )
        }
    }
}
