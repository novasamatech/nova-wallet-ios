import RobinHood

protocol BondingAccountSigningFactoryProtocol {
    func createSigner() -> CompoundOperationWrapper<SigningWrapperProtocol?>
    func createExtrinsicService() -> CompoundOperationWrapper<ExtrinsicServiceProtocol?>
}

final class BondingAccountSigningFactory: BondingAccountSigningFactoryProtocol {
    let signingWrapperFactory: SigningWrapperFactoryProtocol
    let controllerChainAccountResponse: ChainAccountResponse
    let extrinsicServiceFactory: ExtrinsicServiceFactoryProtocol
    let accountRepositoryFactory: AccountRepositoryFactoryProtocol
    let chainAsset: ChainAsset
    let stashAddress: AccountAddress

    init(
        signingWrapperFactory: SigningWrapperFactoryProtocol,
        controllerChainAccountResponse: ChainAccountResponse,
        extrinsicServiceFactory: ExtrinsicServiceFactoryProtocol,
        accountRepositoryFactory: AccountRepositoryFactoryProtocol,
        chainAsset: ChainAsset,
        stashAddress: AccountAddress
    ) {
        self.signingWrapperFactory = signingWrapperFactory
        self.controllerChainAccountResponse = controllerChainAccountResponse
        self.extrinsicServiceFactory = extrinsicServiceFactory
        self.accountRepositoryFactory = accountRepositoryFactory
        self.chainAsset = chainAsset
        self.stashAddress = stashAddress
    }

    func createSigner() -> CompoundOperationWrapper<SigningWrapperProtocol?> {
        let extrinsicSenderOperation = resolvedMetaChainAccountResponse()

        let mapOperation = ClosureOperation<SigningWrapperProtocol?> {
            if let extrinsicSender = try extrinsicSenderOperation.targetOperation.extractNoCancellableResultData() {
                let signer = self.signingWrapperFactory.createSigningWrapper(
                    for: extrinsicSender.metaId,
                    accountResponse: extrinsicSender.chainAccount
                )

                return signer
            } else {
                return nil
            }
        }

        extrinsicSenderOperation.allOperations.forEach {
            mapOperation.addDependency($0)
        }

        return CompoundOperationWrapper(
            targetOperation: mapOperation,
            dependencies: extrinsicSenderOperation.allOperations
        )
    }

    func createExtrinsicService() -> CompoundOperationWrapper<ExtrinsicServiceProtocol?> {
        let extrinsicSenderOperation = resolvedMetaChainAccountResponse()
        let mapOperation = ClosureOperation<ExtrinsicServiceProtocol?> {
            if let extrinsicSender = try extrinsicSenderOperation.targetOperation.extractNoCancellableResultData() {
                let extrinsicService = self.extrinsicServiceFactory.createService(
                    account: extrinsicSender.chainAccount,
                    chain: self.chainAsset.chain
                )
                return extrinsicService
            } else {
                return nil
            }
        }

        mapOperation.addDependency(extrinsicSenderOperation.targetOperation)

        return CompoundOperationWrapper(
            targetOperation: mapOperation,
            dependencies: extrinsicSenderOperation.allOperations
        )
    }

    func resolvedMetaChainAccountResponse() -> CompoundOperationWrapper<MetaChainAccountResponse?> {
        let accountId = resolvedAccountId() ?? controllerChainAccountResponse.accountId
        let repository = accountRepositoryFactory.createMetaAccountRepository(
            for: NSPredicate.filterMetaAccountByAccountId(accountId),
            sortDescriptors: [NSSortDescriptor.accountsByOrder]
        )
        let fetchAcccountsOperation = repository.fetchAllOperation(with: .init())

        let mapOperation = ClosureOperation<MetaChainAccountResponse?> {
            let fetchResult = try fetchAcccountsOperation.extractNoCancellableResultData()
            let chainAccountRequest = self.chainAsset.chain.accountRequest()
            if let metaAccount = fetchResult.first(where: { $0.type != .watchOnly }) ?? fetchResult.first {
                return metaAccount.fetchMetaChainAccount(for: chainAccountRequest)
            } else {
                return nil
            }
        }

        mapOperation.addDependency(fetchAcccountsOperation)

        return CompoundOperationWrapper(targetOperation: mapOperation, dependencies: [fetchAcccountsOperation])
    }

    func resolvedAccountId() -> AccountId? {
        if let controllerAddress = controllerChainAccountResponse.toAddress(),
           stashAddress == controllerAddress {
            let chainFormat = chainAsset.chain.chainFormat
            return try? stashAddress.toAccountId(using: chainFormat)
        }

        return controllerChainAccountResponse.accountId
    }
}
