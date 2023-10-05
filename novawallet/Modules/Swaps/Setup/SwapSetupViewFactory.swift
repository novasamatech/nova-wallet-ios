import Foundation
import SoraFoundation
import RobinHood

struct SwapSetupViewFactory {
    static func createView() -> SwapSetupViewProtocol? {
        guard
            let currencyManager = CurrencyManager.shared else {
            return nil
        }

        let balanceViewModelFactory = BalanceViewModelFactoryFacade(
            priceAssetInfoFactory: PriceAssetInfoFactory(currencyManager: currencyManager))

        guard let interactor = createInteractor() else {
            return nil
        }

        let wireframe = SwapSetupWireframe()

        let presenter = SwapSetupPresenter(
            interactor: interactor,
            wireframe: wireframe,
            balanceViewModelFactory: balanceViewModelFactory,
            localizationManager: LocalizationManager.shared
        )

        let view = SwapSetupViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }

    private static func createInteractor() -> SwapSetupInteractor? {
        let westmintChainId = KnowChainId.westmint
        let chainRegistry = ChainRegistryFacade.sharedRegistry

        guard let connection = chainRegistry.getConnection(for: westmintChainId),
              let runtimeService = chainRegistry.getRuntimeProvider(for: westmintChainId),
              let chainModel = chainRegistry.getChain(for: westmintChainId) else {
            return nil
        }

        let operationQueue = OperationManagerFacade.sharedDefaultQueue

        let assetConversionOperationFactory = AssetHubSwapOperationFactory(
            chain: chainModel,
            runtimeService: runtimeService,
            connection: connection,
            operationQueue: operationQueue
        )
        let extrinsicServiceFactory = ExtrinsicServiceFactory(
            runtimeRegistry: runtimeService,
            engine: connection,
            operationManager: OperationManager(operationQueue: operationQueue)
        )

        let interactor = SwapSetupInteractor(
            assetConversionOperationFactory: assetConversionOperationFactory,
            assetConversionExtrinsicService: AssetHubExtrinsicService(chain: chainModel),
            runtimeService: runtimeService,
            feeProxy: ExtrinsicFeeProxy(),
            extrinsicServiceFactory: extrinsicServiceFactory,
            operationQueue: operationQueue
        )

        return interactor
    }
}
