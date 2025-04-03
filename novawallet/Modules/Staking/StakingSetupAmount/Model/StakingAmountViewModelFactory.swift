import Foundation
import Foundation_iOS
import BigInt

protocol StakingAmountViewModelFactoryProtocol {
    func balance(amount: BigUInt?, chainAsset: ChainAsset, locale: Locale) -> TitleHorizontalMultiValueView.Model

    func maxApy(for stakingType: SelectedStakingOption, locale: Locale) -> String
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

    func maxApy(for stakingType: SelectedStakingOption, locale: Locale) -> String {
        let maxApy = stakingType.maxApy ?? 0
        return estimatedEarningsFormatter.value(for: locale).stringFromDecimal(maxApy) ?? ""
    }
}
