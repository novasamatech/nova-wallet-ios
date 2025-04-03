import Foundation
import Operation_iOS
import Foundation_iOS
import BigInt

struct ChainAssetSelectionViewFactory {
    static func createView(
        delegate: ChainAssetSelectionDelegate,
        selectedChainAssetId: ChainAssetId?,
        balanceSlice: KeyPath<AssetBalance, BigUInt>? = nil,
        assetFilter: @escaping ChainAssetSelectionFilter
    ) -> ChainAssetSelectionViewProtocol? {
        guard let currencyManager = CurrencyManager.shared else {
            return nil
        }
        let repository = ChainRepositoryFactory().createRepository(
            for: nil,
            sortDescriptors: [NSSortDescriptor.chainsByAddressPrefix]
        )

        let interactor = ChainAssetSelectionInteractor(
            selectedMetaAccount: SelectedWalletSettings.shared.value,
            repository: AnyDataProviderRepository(repository),
            walletLocalSubscriptionFactory: WalletLocalSubscriptionFactory.shared,
            priceLocalSubscriptionFactory: PriceProviderFactory.shared,
            assetFilter: assetFilter,
            currencyManager: currencyManager,
            operationQueue: OperationManagerFacade.sharedDefaultQueue
        )

        let wireframe = ChainAssetSelectionWireframe()
        wireframe.delegate = delegate

        let assetBalanceFormatterFactory = AssetBalanceFormatterFactory()

        let localizationManager = LocalizationManager.shared
        let assetIconViewModelFactory = AssetIconViewModelFactory()

        let presenter = ChainAssetSelectionPresenter(
            interactor: interactor,
            wireframe: wireframe,
            selectedChainAssetId: selectedChainAssetId,
            balanceMapper: AvailableBalanceSliceMapper(balanceSlice: balanceSlice ?? \.transferable),
            assetBalanceFormatterFactory: assetBalanceFormatterFactory,
            assetIconViewModelFactory: assetIconViewModelFactory,
            localizationManager: localizationManager
        )

        let title = LocalizableResource { locale in
            R.string.localizable.commonSelectNetwork(preferredLanguages: locale.rLanguages)
        }

        let view = ChainAssetSelectionViewController(
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
