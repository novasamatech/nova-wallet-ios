import Foundation
import RobinHood
import SoraFoundation

struct AssetSelectionViewFactory {
    static func createView(
        delegate: AssetSelectionDelegate,
        selectedChainAssetId: ChainAssetId?,
        assetFilter: @escaping AssetSelectionFilter
    ) -> AssetSelectionViewProtocol? {
        let repository = ChainRepositoryFactory().createRepository(
            for: nil,
            sortDescriptors: [NSSortDescriptor.chainsByAddressPrefix]
        )

        let interactor = AssetSelectionInteractor(
            selectedMetaAccount: SelectedWalletSettings.shared.value,
            repository: AnyDataProviderRepository(repository),
            walletLocalSubscriptionFactory: WalletLocalSubscriptionFactory.shared,
            priceLocalSubscriptionFactory: PriceProviderFactory.shared,
            assetFilter: assetFilter,
            operationQueue: OperationManagerFacade.sharedDefaultQueue
        )

        let wireframe = AssetSelectionWireframe()
        wireframe.delegate = delegate

        let assetBalanceFormatterFactory = AssetBalanceFormatterFactory()

        let localizationManager = LocalizationManager.shared

        let presenter = AssetSelectionPresenter(
            interactor: interactor,
            wireframe: wireframe,
            selectedChainAssetId: selectedChainAssetId,
            assetBalanceFormatterFactory: assetBalanceFormatterFactory,
            localizationManager: localizationManager
        )

        let title = LocalizableResource { locale in
            R.string.localizable.commonSelectAsset(preferredLanguages: locale.rLanguages)
        }

        let view = AssetSelectionViewController(
            nibName: R.nib.selectionListViewController.name,
            localizedTitle: title,
            presenter: presenter,
            localizationManager: localizationManager
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
