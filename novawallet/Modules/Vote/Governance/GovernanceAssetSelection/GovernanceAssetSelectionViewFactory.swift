import Foundation
import RobinHood
import SoraFoundation

final class GovernanceAssetSelectionViewFactory {
    static func createView(
        for delegate: GovernanceAssetSelectionDelegate,
        chainId: ChainModel.Id?,
        governanceType: GovernanceType?
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
            balanceSlice: \.freeInPlank,
            repository: AnyDataProviderRepository(repository),
            walletLocalSubscriptionFactory: WalletLocalSubscriptionFactory.shared,
            priceLocalSubscriptionFactory: PriceProviderFactory.shared,
            assetFilter: { $0.chain.hasGovernance && $0.asset.isUtility },
            currencyManager: currencyManager,
            operationQueue: OperationManagerFacade.sharedDefaultQueue
        )

        let wireframe = GovernanceAssetSelectionWireframe(delegate: delegate)

        let assetBalanceFormatterFactory = AssetBalanceFormatterFactory()

        let localizationManager = LocalizationManager.shared

        let presenter = GovernanceAssetSelectionPresenter(
            interactor: interactor,
            wireframe: wireframe,
            selectedChainId: chainId,
            selectedGovernanceType: governanceType,
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
