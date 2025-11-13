import Foundation

final class WalletsChooseViewModelFactory: WalletsListViewModelFactory {
    let selectedId: String

    init(
        selectedId: String,
        assetBalanceFormatterFactory: AssetBalanceFormatterFactoryProtocol,
        priceAssetInfoFactory: PriceAssetInfoFactoryProtocol,
        currencyManager: CurrencyManagerProtocol
    ) {
        self.selectedId = selectedId

        super.init(
            assetBalanceFormatterFactory: assetBalanceFormatterFactory,
            priceAssetInfoFactory: priceAssetInfoFactory,
            currencyManager: currencyManager
        )
    }

    override func isSelected(wallet: ManagedMetaAccountModel) -> Bool {
        wallet.info.metaId == selectedId
    }
}
