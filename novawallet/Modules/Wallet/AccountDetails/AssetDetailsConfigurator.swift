import Foundation
import CommonWallet
import SoraFoundation
import UIKit

final class AssetDetailsConfigurator {
    let containingViewFactory: AssetDetailsContainingViewFactory
    let viewModelFactory: AssetDetailsViewModelFactory

    init(
        address: AccountAddress,
        chainAsset: ChainAsset,
        purchaseProvider: PurchaseProviderProtocol,
        priceAsset: WalletAsset,
        localizationManager: LocalizationManagerProtocol
    ) {
        let amountFormatterFactory = AmountFormatterFactory()

        containingViewFactory = AssetDetailsContainingViewFactory(
            chainAsset: chainAsset,
            localizationManager: localizationManager
        )

        viewModelFactory = AssetDetailsViewModelFactory(
            address: address,
            chain: chainAsset.chain,
            purchaseProvider: purchaseProvider,
            amountFormatterFactory: amountFormatterFactory,
            priceAsset: priceAsset
        )
    }

    func bind(commandFactory: WalletCommandFactoryProtocol) {
        containingViewFactory.commandFactory = commandFactory
    }

    func configure(builder: AccountDetailsModuleBuilderProtocol) {
        builder
            .with(containingViewFactory: containingViewFactory)
            .with(listViewModelFactory: viewModelFactory)
            .with(localizableTitle: LocalizableResource { _ in "" })
            .with(additionalInsets: .zero)
    }
}
