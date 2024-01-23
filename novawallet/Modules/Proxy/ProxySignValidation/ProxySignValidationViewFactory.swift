import UIKit
import SubstrateSdk
import SoraFoundation

struct ProxySignValidationViewFactory {
    static func createView(
        from viewController: UIViewController,
        resolvedProxy: ExtrinsicSenderResolution.ResolvedProxy,
        calls: [JSON],
        completionClosure: @escaping ProxySignValidationCompletion
    ) -> ProxySignValidationPresenterProtocol? {
        guard
            let utilityChainAsset = resolvedProxy.chain.utilityChainAsset(),
            let currencyManager = CurrencyManager.shared,
            let interactor = createInteractor(resolvedProxy: resolvedProxy, calls: calls) else {
            return nil
        }

        let wireframe = ProxySignValidationWireframe()

        let view = ControllerBacked(controller: viewController)

        let dataValidatorFactory = ProxyDataValidatorFactory(presentable: wireframe)

        dataValidatorFactory.view = view

        let presenter = ProxySignValidationPresenter(
            view: view,
            interactor: interactor,
            wireframe: wireframe,
            proxyName: resolvedProxy.proxyAccount?.chainAccount.name ?? "",
            dataValidationFactory: dataValidatorFactory,
            chainAsset: utilityChainAsset,
            completionClosure: completionClosure,
            localizationManager: LocalizationManager.shared,
            logger: Logger.shared
        )

        interactor.presenter = presenter

        return presenter
    }

    static func createInteractor(
        resolvedProxy: ExtrinsicSenderResolution.ResolvedProxy,
        calls: [JSON]
    ) -> ProxySignValidationInteractor? {
        let chainRegistry = ChainRegistryFacade.sharedRegistry
        let chain = resolvedProxy.chain

        guard
            let proxyAccount = resolvedProxy.proxyAccount,
            let chainAsset = chain.utilityChainAsset(),
            let runtimeProvider = chainRegistry.getRuntimeProvider(for: chain.chainId),
            let connection = chainRegistry.getConnection(for: chain.chainId) else {
            return nil
        }

        let extrinsicService = ExtrinsicServiceFactory(
            runtimeRegistry: runtimeProvider,
            engine: connection,
            operationManager: OperationManagerFacade.sharedManager,
            userStorageFacade: UserDataStorageFacade.shared
        ).createService(account: proxyAccount.chainAccount, chain: chain)

        let assetInfoOperationFactory = AssetStorageInfoOperationFactory()

        let balanceQueryFactory = WalletRemoteQueryWrapperFactory(
            requestFactory: StorageRequestFactory(
                remoteFactory: StorageKeyFactory(),
                operationManager: OperationManagerFacade.sharedManager
            ),
            assetInfoOperationFactory: assetInfoOperationFactory,
            runtimeProvider: runtimeProvider,
            connection: connection,
            operationQueue: OperationManagerFacade.sharedDefaultQueue
        )

        return .init(
            selectedAccount: proxyAccount,
            chainAsset: chainAsset,
            extrinsicService: extrinsicService,
            runtimeProvider: runtimeProvider,
            balanceQueryFactory: balanceQueryFactory,
            assetInfoOperationFactory: assetInfoOperationFactory,
            calls: calls,
            operationQueue: OperationManagerFacade.sharedDefaultQueue
        )
    }
}
