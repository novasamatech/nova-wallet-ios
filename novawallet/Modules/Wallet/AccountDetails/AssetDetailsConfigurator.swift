import Foundation
import CommonWallet
import SoraFoundation
import UIKit

final class AssetDetailsConfigurator {
    let viewModelFactory: AssetDetailsViewModelFactory

    init(
        address: AccountAddress,
        chain: ChainModel,
        purchaseProvider: PurchaseProviderProtocol,
        priceAsset: WalletAsset
    ) {
        let amountFormatterFactory = AmountFormatterFactory()

        viewModelFactory = AssetDetailsViewModelFactory(
            address: address,
            chain: chain,
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
