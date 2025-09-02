import Foundation
import SubstrateSdk
import Operation_iOS

extension IdentityProxyFactory {
    static func createDefaultProxy(
        from originChain: ChainModel,
        chainRegistry: ChainRegistryProtocol,
        operationQueue: OperationQueue = OperationManagerFacade.sharedDefaultQueue
    ) -> IdentityProxyFactory {
        let storageKeyFactory = StorageKeyFactory()
        let operationManager = OperationManager(operationQueue: operationQueue)

        let storageRequestFactory = StorageRequestFactory(
            remoteFactory: storageKeyFactory,
            operationManager: operationManager
        )

        let operationFactory = IdentityOperationFactory(requestFactory: storageRequestFactory)

        return IdentityProxyFactory(
            originChain: originChain,
            chainRegistry: chainRegistry,
            identityOperationFactory: operationFactory
        )
    }
}
