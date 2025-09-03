import Foundation
import Operation_iOS

protocol ExtrinsicSenderResolutionFactoryProtocol {
    func createWrapper() -> CompoundOperationWrapper<ExtrinsicSenderResolving>
}

final class ExtrinsicSenderResolutionFactory {
    let userStorageFacade: StorageFacadeProtocol
    let chain: ChainModel
    let chainAccount: ChainAccountResponse

    init(
        chainAccount: ChainAccountResponse,
        chain: ChainModel,
        userStorageFacade: StorageFacadeProtocol
    ) {
        self.chainAccount = chainAccount
        self.chain = chain
        self.userStorageFacade = userStorageFacade
    }

    private func createCurrentResolver(
        for chainAccount: ChainAccountResponse
    ) -> CompoundOperationWrapper<ExtrinsicSenderResolving> {
        let resolver = ExtrinsicCurrentSenderResolver(currentAccount: chainAccount)
        return CompoundOperationWrapper.createWithResult(resolver)
    }

    private func createDelegateResolver(
        for delegatedAccount: ChainAccountResponse,
        chain: ChainModel
    ) -> CompoundOperationWrapper<ExtrinsicSenderResolving> {
        let repository = AccountRepositoryFactory(storageFacade: userStorageFacade).createMetaAccountRepository(
            for: nil,
            sortDescriptors: []
        )

        let fetchOperation = repository.fetchAllOperation(with: .init())

        let mappingOperation = ClosureOperation<ExtrinsicSenderResolving> {
            let wallets = try fetchOperation.extractNoCancellableResultData()

            guard let delegateAccountId = wallets.first(
                where: { $0.metaId == delegatedAccount.metaId }
            )?.getDelegateIdentifier()?.delegateAccountId
            else {
                throw ChainAccountFetchingError.accountNotExists
            }

            let callWrapper = try DelegatedCallWrapperFactory.createCallWrapper(
                for: delegatedAccount,
                delegateAccountId: delegateAccountId
            )

            return ExtrinsicDelegateSenderResolver(
                delegatedAccount: delegatedAccount,
                delegateAccountId: delegateAccountId,
                callWrapper: callWrapper,
                wallets: wallets,
                chain: chain
            )
        }

        mappingOperation.addDependency(fetchOperation)

        return CompoundOperationWrapper(targetOperation: mappingOperation, dependencies: [fetchOperation])
    }
}

extension ExtrinsicSenderResolutionFactory: ExtrinsicSenderResolutionFactoryProtocol {
    func createWrapper() -> CompoundOperationWrapper<ExtrinsicSenderResolving> {
        switch chainAccount.type {
        case .secrets, .paritySigner, .polkadotVault, .ledger, .watchOnly, .genericLedger:
            createCurrentResolver(for: chainAccount)
        case .proxied, .multisig:
            createDelegateResolver(
                for: chainAccount,
                chain: chain
            )
        }
    }
}

protocol ExtrinsicSenderResolutionFacadeProtocol {
    func createResolutionFactory(
        for chainAccount: ChainAccountResponse,
        chainModel: ChainModel
    ) -> ExtrinsicSenderResolutionFactoryProtocol
}

final class ExtrinsicSenderResolutionFacade {
    let userStorageFacade: StorageFacadeProtocol

    init(userStorageFacade: StorageFacadeProtocol) {
        self.userStorageFacade = userStorageFacade
    }
}

extension ExtrinsicSenderResolutionFacade: ExtrinsicSenderResolutionFacadeProtocol {
    func createResolutionFactory(
        for chainAccount: ChainAccountResponse,
        chainModel: ChainModel
    ) -> ExtrinsicSenderResolutionFactoryProtocol {
        ExtrinsicSenderResolutionFactory(
            chainAccount: chainAccount,
            chain: chainModel,
            userStorageFacade: userStorageFacade
        )
    }
}
