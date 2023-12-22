import Foundation
import RobinHood

protocol ExtrinsicSenderResolutionFactoryProtocol {
    func createWrapper() -> CompoundOperationWrapper<ExtrinsicSenderResolving>
}

final class ExtrinsicSenderResolutionFactory {
    let userStorageFacade: StorageFacadeProtocol
    let chain: ChainModel
    let chainAccount: ChainAccountResponse?

    init(
        chainAccount: ChainAccountResponse?,
        chain: ChainModel,
        userStorageFacade: StorageFacadeProtocol
    ) {
        self.chainAccount = chainAccount
        self.chain = chain
        self.userStorageFacade = userStorageFacade
    }

    private func createCurrentResolver() -> CompoundOperationWrapper<ExtrinsicSenderResolving> {
        let resolver = ExtrinsicCurrentSenderResolver()
        return CompoundOperationWrapper.createWithResult(resolver)
    }

    private func createProxyResolver(
        for _: ChainAccountResponse
    ) -> CompoundOperationWrapper<ExtrinsicSenderResolving> {
        let repository = AccountRepositoryFactory(storageFacade: userStorageFacade).createMetaAccountRepository(
            for: nil,
            sortDescriptors: []
        )

        let fetchOperation = repository.fetchAllOperation(with: .init())

        let mappingOperation = ClosureOperation<ExtrinsicSenderResolving> {
            let wallets = try fetchOperation.extractNoCancellableResultData()
            return ExtrinsicProxySenderResolver(wallets: wallets)
        }

        mappingOperation.addDependency(fetchOperation)

        return CompoundOperationWrapper(targetOperation: mappingOperation, dependencies: [fetchOperation])
    }
}

extension ExtrinsicSenderResolutionFactory: ExtrinsicSenderResolutionFactoryProtocol {
    func createWrapper() -> CompoundOperationWrapper<ExtrinsicSenderResolving> {
        guard let chainAccount = chainAccount else {
            return createCurrentResolver()
        }

        switch chainAccount.type {
        case .secrets, .paritySigner, .polkadotVault, .ledger, .watchOnly:
            return createCurrentResolver()
        case .proxied:
            return createProxyResolver(for: chainAccount)
        }
    }
}
