import Foundation
import CommonWallet

final class WalletAccountListConfigurator {
    let logger: LoggerProtocol

    let viewModelFactory: WalletAssetViewModelFactory
    let assetStyleFactory: AssetStyleFactory

    init(
        metaAccount: MetaAccountModel,
        chains: [ChainModel.Id: ChainModel],
        priceAsset: WalletAsset,
        logger: LoggerProtocol
    ) {
        self.logger = logger

        assetStyleFactory = AssetStyleFactory()

        let amountFormatterFactory = AmountFormatterFactory()
        let accountCommandFactory = WalletSelectAccountCommandFactory()

        viewModelFactory = WalletAssetViewModelFactory(
            metaAccount: metaAccount,
            chains: chains,
            assetCellStyleFactory: assetStyleFactory,
            amountFormatterFactory: amountFormatterFactory,
            priceAsset: priceAsset,
            accountCommandFactory: accountCommandFactory
        )
    }

    func configure(builder: AccountListModuleBuilderProtocol) {
        do {
            var viewStyle = AccountListViewStyle(refreshIndicatorStyle: R.color.colorWhite()!)
            viewStyle.backgroundImage = R.image.backgroundImage()

            try builder
                .with(
                    cellNib: UINib(resource: R.nib.walletTotalPriceCell),
                    for: WalletAccountListConstants.totalPriceCellId
                )
                .with(
                    cellNib: UINib(resource: R.nib.walletAssetCell),
                    for: WalletAccountListConstants.assetCellId
                )
                .with(
                    cellNib: UINib(resource: R.nib.walletActionsCell),
                    for: WalletAccountListConstants.actionsCellId
                )
                .with(listViewModelFactory: viewModelFactory)
                .with(assetCellStyleFactory: assetStyleFactory)
                .with(viewStyle: viewStyle)
                .with(minimumVisibleAssets: 1000)
        } catch {
            logger.error("Can't customize account list: \(error)")
        }
    }
}
