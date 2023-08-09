import Foundation
import SoraFoundation
import BigInt

protocol StakingAmountViewModelFactoryProtocol {
    func balance(amount: BigUInt?, chainAsset: ChainAsset, locale: Locale) -> TitleHorizontalMultiValueView.Model

    func recommendedStakingTypeViewModel(
        for stakingType: SelectedStakingOption,
        chainAsset: ChainAsset,
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
        chainAsset: ChainAsset,
        locale: Locale
    ) -> StakingTypeViewModel {
        let amount = stakingType.maxApy.flatMap {
            estimatedEarningsFormatter.value(for: locale).stringFromDecimal($0)
        }

        switch stakingType {
        case .direct:
            return StakingTypeViewModel(
                icon: nil,
                title: R.string.localizable.stakingDirectStaking(preferredLanguages: locale.rLanguages),
                subtitle: R.string.localizable.commonRecommended(preferredLanguages: locale.rLanguages),
                isRecommended: true,
                maxApy: amount ?? "",
                shouldEnableSelection: chainAsset.asset.hasMultipleStakingOptions
            )
        case .pool:
            return StakingTypeViewModel(
                icon: nil,
                title: R.string.localizable.stakingPoolStaking(preferredLanguages: locale.rLanguages),
                subtitle: R.string.localizable.commonRecommended(preferredLanguages: locale.rLanguages),
                isRecommended: true,
                maxApy: amount ?? "",
                shouldEnableSelection: chainAsset.asset.hasMultipleStakingOptions
            )
        }
    }
}
