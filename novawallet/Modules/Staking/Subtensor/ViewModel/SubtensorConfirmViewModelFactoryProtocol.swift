import Foundation

protocol SubtensorConfirmViewModelFactoryProtocol {
    func createViewModel(for input: SubtensorConfirmViewModelInput, locale: Locale) -> SubtensorConfirmViewModel

    func createViewModel(for input: SubtensorUnstakeConfirmViewModelInput, locale: Locale) -> SubtensorConfirmViewModel

    func createTileIcons(
        for target: SubtensorStakeTarget,
        direction: SubtensorTradeDirection,
        catalogue: SubtensorSubnetCatalogue?,
        subnetLogos: SubtensorSubnetLogos?
    ) -> SubtensorConfirmTileIconsViewModel

    func amountDisplayInfo(
        for target: SubtensorStakeTarget,
        catalogue: SubtensorSubnetCatalogue?
    ) -> AssetBalanceDisplayInfo
}
