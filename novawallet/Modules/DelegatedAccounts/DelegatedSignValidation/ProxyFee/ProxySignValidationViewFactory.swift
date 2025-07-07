import UIKit
import SubstrateSdk
import Foundation_iOS

struct ProxySignValidationViewFactory {
    static func createPresenter(
        from view: ControllerBackedProtocol,
        callSender: MetaChainAccountResponse,
        call: AnyRuntimeCall,
        validationSharedData: DelegatedSignValidationSharedData,
        completionClosure: @escaping DelegatedSignValidationCompletion
    ) -> DSFeeValidationPresenterProtocol? {
        guard
            let chain = ChainRegistryFacade.sharedRegistry.getChain(
                for: callSender.chainAccount.chainId
            ),
            let utilityChainAsset = chain.utilityChainAsset(),
            let currencyManager = CurrencyManager.shared,
            let interactor = createInteractor(
                callSender: callSender,
                chain: chain,
                call: call,
                validationSharedData: validationSharedData
            ) else {
            return nil
        }

        let wireframe = ProxySignValidationWireframe()

        let priceAssetInfoFactory = PriceAssetInfoFactory(currencyManager: currencyManager)

        let dataValidatorFactory = ProxyDataValidatorFactory(
            presentable: wireframe,
            balanceViewModelFactoryFacade: BalanceViewModelFactoryFacade(
                priceAssetInfoFactory: priceAssetInfoFactory
            )
        )

        dataValidatorFactory.view = view

        let presenter = ProxySignValidationPresenter(
            view: view,
            interactor: interactor,
            wireframe: wireframe,
            proxyName: callSender.chainAccount.name,
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
        callSender: MetaChainAccountResponse,
        chain: ChainModel,
        call: AnyRuntimeCall,
        validationSharedData: DelegatedSignValidationSharedData
    ) -> DSFeeValidationInteractor? {
        let chainRegistry = ChainRegistryFacade.sharedRegistry

        guard
            let chainAsset = chain.utilityChainAsset(),
            let runtimeProvider = chainRegistry.getRuntimeProvider(for: chain.chainId),
            let connection = chainRegistry.getConnection(for: chain.chainId) else {
            return nil
        }

        let extrinsicService = ExtrinsicServiceFactory(
            runtimeRegistry: runtimeProvider,
            engine: connection,
            operationQueue: OperationManagerFacade.sharedDefaultQueue,
            userStorageFacade: UserDataStorageFacade.shared,
            substrateStorageFacade: SubstrateDataStorageFacade.shared
        ).createService(account: callSender.chainAccount, chain: chain)

        let assetInfoOperationFactory = AssetStorageInfoOperationFactory()

        let balanceQueryFactory = WalletRemoteQueryWrapperFactory(
            requestFactory: StorageRequestFactory(
                remoteFactory: StorageKeyFactory(),
                operationManager: OperationManagerFacade.sharedManager
            ),
            runtimeProvider: runtimeProvider,
            connection: connection,
            operationQueue: OperationManagerFacade.sharedDefaultQueue
        )

        return .init(
            selectedAccount: callSender,
            chainAsset: chainAsset,
            extrinsicService: extrinsicService,
            runtimeProvider: runtimeProvider,
            balanceQueryFactory: balanceQueryFactory,
            assetInfoOperationFactory: assetInfoOperationFactory,
            call: call,
            validationSharedData: validationSharedData,
            operationQueue: OperationManagerFacade.sharedDefaultQueue
        )
    }
}
