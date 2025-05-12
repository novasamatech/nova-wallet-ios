import Foundation
import SubstrateSdk
import Operation_iOS

extension IdentityDelegatedAccountFactory {
    static func createDefaultProxy(
        from originChain: ChainModel,
        chainRegistry: ChainRegistryProtocol,
        operationQueue: OperationQueue = OperationManagerFacade.sharedDefaultQueue
    ) -> IdentityDelegatedAccountFactory {
        let storageKeyFactory = StorageKeyFactory()
        let operationManager = OperationManager(operationQueue: operationQueue)

        let storageRequestFactory = StorageRequestFactory(
            remoteFactory: storageKeyFactory,
            operationManager: operationManager
        )

        let operationFactory = IdentityOperationFactory(requestFactory: storageRequestFactory)

        return IdentityDelegatedAccountFactory(
            originChain: originChain,
            chainRegistry: chainRegistry,
            identityOperationFactory: operationFactory
        )
    }
}
