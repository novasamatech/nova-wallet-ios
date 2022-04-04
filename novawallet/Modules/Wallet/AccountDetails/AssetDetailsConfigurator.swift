import Foundation
import CommonWallet
import SoraFoundation
import UIKit

final class AssetDetailsConfigurator {
    let containingViewFactory: AssetDetailsContainingViewFactory
    let viewModelFactory: AssetDetailsViewModelFactory

    init(
        accountId: AccountId,
        chainAsset: ChainAsset,
        purchaseProvider: PurchaseProviderProtocol,
        priceAsset: WalletAsset,
        localizationManager: LocalizationManagerProtocol
    ) {
        let amountFormatterFactory = AmountFormatterFactory()

        containingViewFactory = AssetDetailsContainingViewFactory(
            chainAsset: chainAsset,
            localizationManager: localizationManager,
            purchaseProvider: purchaseProvider,
            selectedAccountId: accountId
        )

        viewModelFactory = AssetDetailsViewModelFactory(
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
