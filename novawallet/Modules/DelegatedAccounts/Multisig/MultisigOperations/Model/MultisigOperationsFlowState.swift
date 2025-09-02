import Foundation
import Foundation_iOS
import Operation_iOS

final class MultisigOperationsFlowState {
    private let callFormattingCache = InMemoryCache<Substrate.CallHash, FormattedCall>()
}

extension MultisigOperationsFlowState {
    func getOperationProviderProxy(
        storageFacade: StorageFacadeProtocol = UserDataStorageFacade.shared,
        chainRegistry: ChainRegistryProtocol = ChainRegistryFacade.sharedRegistry
    ) -> MultisigOperationProviderProxyProtocol {
        let operationQueue = OperationManagerFacade.sharedDefaultQueue

        let walletRepository = AccountRepositoryFactory(
            storageFacade: storageFacade
        ).createMetaAccountRepository(for: nil, sortDescriptors: [])

        let chainProvider = ChainRegistryChainProvider(chainRegistry: chainRegistry)
        let runtimeCodingServiceProvider = ChainRegistryRuntimeCodingServiceProvider(chainRegistry: chainRegistry)

        return MultisigOperationProviderProxy(
            pendingMultisigLocalSubscriptionFactory: MultisigOperationsLocalSubscriptionFactory.shared,
            callFormattingFactory: CallFormattingOperationFactory(
                chainProvider: chainProvider,
                runtimeCodingServiceProvider: runtimeCodingServiceProvider,
                walletRepository: walletRepository,
                operationQueue: operationQueue
            ),
            formattingCache: callFormattingCache,
            operationQueue: operationQueue
        )
    }
}
