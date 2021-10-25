import Foundation
import CommonWallet
import SoraFoundation

final class AssetDetailsConfigurator {
    let viewModelFactory: AssetDetailsViewModelFactory

    init(
        metaAccount: MetaAccountModel,
        chains: [ChainModel.Id: ChainModel],
        purchaseProvider: PurchaseProviderProtocol,
        priceAsset: WalletAsset
    ) {
        let amountFormatterFactory = AmountFormatterFactory()

        viewModelFactory = AssetDetailsViewModelFactory(
            metaAccount: metaAccount,
            chains: chains,
            purchaseProvider: purchaseProvider,
            amountFormatterFactory: amountFormatterFactory,
            priceAsset: priceAsset
        )
    }

    func configure(builder: AccountDetailsModuleBuilderProtocol) {
        let containingViewFactory = AssetDetailsContainingViewFactory()
        builder
            .with(containingViewFactory: containingViewFactory)
            .with(listViewModelFactory: viewModelFactory)
            .with(localizableTitle: LocalizableResource { _ in "" })
            .with(additionalInsets: .zero)
    }
}
