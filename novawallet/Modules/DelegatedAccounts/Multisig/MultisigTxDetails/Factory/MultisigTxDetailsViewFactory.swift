import Foundation
import Foundation_iOS

final class MultisigTxDetailsViewFactory {
    static func createView(for pendingOperation: Multisig.PendingOperation) -> MultisigTxDetailsViewProtocol? {
        let chainRegistry = ChainRegistryFacade.sharedRegistry

        guard
            let chain = chainRegistry.getChain(for: pendingOperation.chainId),
            let currencyManager = CurrencyManager.shared,
            let asset = chain.utilityAsset()
        else {
            return nil
        }

        let localizationManager = LocalizationManager.shared
        let logger = Logger.shared

        let operationQueue = OperationManagerFacade.sharedDefaultQueue

        let prettyPrintedJSONOperationFactory = PrettyPrintedJSONOperationFactory(
            preprocessor: ExtrinsicJSONProcessor()
        )

        let walletRepository = AccountRepositoryFactory(
            storageFacade: UserDataStorageFacade.shared
        ).createMetaAccountRepository(for: nil, sortDescriptors: [])

        let interactor = MultisigTxDetailsInteractor(
            pendingOperation: pendingOperation,
            priceLocalSubscriptionFactory: PriceProviderFactory.shared,
            chain: chain,
            chainRegistry: chainRegistry,
            prettyPrintedJSONOperationFactory: prettyPrintedJSONOperationFactory,
            walletRepository: walletRepository,
            operationQueue: operationQueue,
            currencyManager: currencyManager,
            logger: logger
        )

        let wireframe = MultisigTxDetailsWireframe()

        let priceAssetInfoFactory = PriceAssetInfoFactory(currencyManager: currencyManager)

        let balanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: asset.displayInfo,
            priceAssetInfoFactory: priceAssetInfoFactory
        )

        let viewModelFactory = MultisigTxDetailsViewModelFactory(
            displayAddressViewModelFactory: DisplayAddressViewModelFactory(),
            utilityBalanceViewModelFactory: balanceViewModelFactory
        )

        let presenter = MultisigTxDetailsPresenter(
            interactor: interactor,
            wireframe: wireframe,
            viewModelFactory: viewModelFactory,
            localizationManager: localizationManager,
            chain: chain,
            logger: logger
        )

        let view = MultisigTxDetailsViewController(presenter: presenter)

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
