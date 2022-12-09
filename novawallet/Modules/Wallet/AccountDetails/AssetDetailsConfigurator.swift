import Foundation
import CommonWallet
import SoraFoundation
import UIKit

final class AssetDetailsConfigurator {
    let containingViewFactory: AssetDetailsContainingViewFactory
    let viewModelFactory: AssetDetailsViewModelFactoryLegacy

    init(
        accountId: AccountId,
        accountType: MetaAccountModelType,
        chainAsset: ChainAsset,
        purchaseProvider: PurchaseProviderProtocol,
        priceAssetFactory: PriceAssetInfoFactoryProtocol,
        localizationManager: LocalizationManagerProtocol
    ) {
        let balanceFormatterFactory = AssetBalanceFormatterFactory()

        containingViewFactory = AssetDetailsContainingViewFactory(
            chainAsset: chainAsset,
            localizationManager: localizationManager,
            purchaseProvider: purchaseProvider,
            selectedAccountId: accountId,
            selectedAccountType: accountType
        )

        viewModelFactory = AssetDetailsViewModelFactoryLegacy(
            balanceFormatterFactory: balanceFormatterFactory,
            priceInfoFactory: priceAssetFactory
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
