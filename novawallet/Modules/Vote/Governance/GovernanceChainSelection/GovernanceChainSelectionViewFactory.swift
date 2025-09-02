import Foundation
import Operation_iOS
import Foundation_iOS

final class GovernanceChainSelectionViewFactory {
    static func createView(
        for delegate: GovernanceChainSelectionDelegate,
        chainId: ChainModel.Id?,
        governanceType: GovernanceType?
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
            assetFilter: {
                $0.chain.syncMode.enabled()
                    && $0.chain.hasGovernance
                    && $0.asset.isUtility
            },
            currencyManager: currencyManager,
            operationQueue: OperationManagerFacade.sharedDefaultQueue
        )

        let wireframe = GovernanceChainSelectionWireframe(delegate: delegate)

        let assetBalanceFormatterFactory = AssetBalanceFormatterFactory()

        let localizationManager = LocalizationManager.shared
        let assetIconViewModelFactory = AssetIconViewModelFactory()

        let presenter = GovernanceChainSelectionPresenter(
            interactor: interactor,
            wireframe: wireframe,
            selectedChainId: chainId,
            selectedGovernanceType: governanceType,
            balanceMapperFactory: GovBalanceCalculatorFactory(),
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
