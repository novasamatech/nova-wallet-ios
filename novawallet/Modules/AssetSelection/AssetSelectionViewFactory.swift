import Foundation
import RobinHood
import SoraFoundation
import BigInt

struct AssetSelectionViewFactory {
    static func createView(
        delegate: AssetSelectionDelegate,
        selectedChainAssetId: ChainAssetId?,
        balanceSlice: KeyPath<AssetBalance, BigUInt>? = nil,
        assetFilter: @escaping AssetSelectionFilter
    ) -> AssetSelectionViewProtocol? {
        guard let currencyManager = CurrencyManager.shared else {
            return nil
        }
        let repository = ChainRepositoryFactory().createRepository(
            for: nil,
            sortDescriptors: [NSSortDescriptor.chainsByAddressPrefix]
        )

        let interactor = AssetSelectionInteractor(
            selectedMetaAccount: SelectedWalletSettings.shared.value,
            balanceSlice: balanceSlice ?? \.transferable,
            repository: AnyDataProviderRepository(repository),
            walletLocalSubscriptionFactory: WalletLocalSubscriptionFactory.shared,
            priceLocalSubscriptionFactory: PriceProviderFactory.shared,
            assetFilter: assetFilter,
            currencyManager: currencyManager,
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
