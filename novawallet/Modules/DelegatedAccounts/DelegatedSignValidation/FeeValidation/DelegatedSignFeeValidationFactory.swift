import Foundation
import SubstrateSdk

enum DSFeeValidationInteractoryFactory {
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
            chainRegistry: chainRegistry,
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
