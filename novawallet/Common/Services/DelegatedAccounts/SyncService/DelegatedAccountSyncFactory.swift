import Foundation
import Operation_iOS

protocol DelegatedAccountSyncFactoryProtocol {
    func createSyncWrapper(
        for chainIds: Set<ChainModel.Id>,
        metaAccountsClosure: @escaping () throws -> [ManagedMetaAccountModel]
    ) -> CompoundOperationWrapper<SyncChanges<ManagedMetaAccountModel>>
}

final class DelegatedAccountSyncFactory {
    let operationQueue: OperationQueue
    let chainRegistry: ChainRegistryProtocol
    let logger: LoggerProtocol

    private let discoveryFactory: DelegatedAccountDiscoveryFactoryProtocol
    private let identityFactory: IdentityProxyFactoryProtocol

    init(
        chainRegistry: ChainRegistryProtocol,
        configProvider: GlobalConfigProviding,
        operationQueue: OperationQueue,
        logger: LoggerProtocol
    ) {
        self.operationQueue = operationQueue
        self.chainRegistry = chainRegistry
        self.logger = logger

        let proxyRepository = DelegatedAccountsRepositoryFacade(
            configProvider: configProvider,
            operationQueue: operationQueue
        ) { config in
            DiscoverProxiesAccountsRepository(url: config.proxyApiUrl)
        }

        let multisigRepository = DelegatedAccountsRepositoryFacade(
            configProvider: configProvider,
            operationQueue: operationQueue
        ) { config in
            DiscoverMultisigAccountsRepository(url: config.multisigsApiUrl)
        }

        discoveryFactory = DelegatedAccountDiscoveryFactory(
            remoteSource: DelegatedAccountsAggregator(
                sources: [proxyRepository, multisigRepository]
            ),
            operationQueue: operationQueue
        )

        identityFactory = MultichainIdentityFactory(
            chainIds: [
                KnowChainId.polkadot,
                KnowChainId.kusama
            ],
            chainRegistry: chainRegistry,
            operationQueue: operationQueue,
            logger: logger
        )
    }
}

// MARK: - Private

private extension DelegatedAccountSyncFactory {
    func createDiscoveryWrapper(
        supportedChainIds: Set<ChainModel.Id>,
        metaAccountsClosure: @escaping () throws -> [ManagedMetaAccountModel]
    ) -> CompoundOperationWrapper<[DiscoveredDelegatedAccountProtocol]> {
        let accountsListWrapper: CompoundOperationWrapper<[DiscoveredDelegatedAccountProtocol]>
        accountsListWrapper = OperationCombiningService.compoundNonOptionalWrapper(
            operationQueue: operationQueue
        ) {
            let metaAccounts = try metaAccountsClosure()

            let possibleDelegateAccountsList: [AccountId] = try metaAccounts.flatMap { wallet in
                guard !wallet.info.isDelegated() else {
                    return [AccountId]()
                }

                let walletAccountIds: [AccountId] = try supportedChainIds.compactMap { chainId in
                    let chain = try self.chainRegistry.getChainOrError(for: chainId)
                    return wallet.info.fetch(for: chain.accountRequest())?.accountId
                }

                return walletAccountIds
            }

            let possibleDelegateAccountsSet = Set(possibleDelegateAccountsList)

            guard !possibleDelegateAccountsSet.isEmpty else {
                return .createWithResult([])
            }

            self.logger.debug("Will start discovery with accounts: \(possibleDelegateAccountsSet.count)")

            return self.discoveryFactory.createDiscoveryWrapper(
                startingFrom: possibleDelegateAccountsSet
            )
        }

        return accountsListWrapper
    }

    func createChangesWrapper(
        dependingOn discoveryWrapper: CompoundOperationWrapper<[DiscoveredDelegatedAccountProtocol]>,
        supportedChains: Set<ChainModel.Id>,
        metaAccountsClosure: @escaping () throws -> [ManagedMetaAccountModel]
    ) -> CompoundOperationWrapper<SyncChanges<ManagedMetaAccountModel>> {
        let accountIdsOperation = ClosureOperation<[AccountId]> {
            let accountIds = try discoveryWrapper
                .targetOperation
                .extractNoCancellableResultData()
                .reduce(into: Set<AccountId>()) {
                    $0.insert($1.accountId)
                    $0.insert($1.delegateAccountId)
                }
                .filter { !$0.matchesEvmAddress() } // evm identities not supported

            return Array(accountIds)
        }

        let identityWrapper = identityFactory.createIdentityWrapperByAccountId(
            for: {
                try accountIdsOperation.extractNoCancellableResultData()
            }
        )

        identityWrapper.addDependency(operations: [accountIdsOperation])

        let mapOperation = ClosureOperation<SyncChanges<ManagedMetaAccountModel>> { [chainRegistry, logger] in
            let metaAccounts = try metaAccountsClosure()
            let identities = try identityWrapper.targetOperation.extractNoCancellableResultData()
            let remoteAccounts = try discoveryWrapper.targetOperation.extractNoCancellableResultData()

            self.logger.debug("Discovered accounts: \(remoteAccounts.count)")
            self.logger.debug("Discovered identities: \(identities.count)")

            return DelegatedAccountsChangesCalculator(
                chainIds: supportedChains,
                chainRegistry: chainRegistry,
                logger: logger
            ).calculateUpdates(
                from: remoteAccounts,
                initialMetaAccounts: metaAccounts,
                identities: identities
            )
        }

        mapOperation.addDependency(identityWrapper.targetOperation)

        return identityWrapper
            .insertingHead(operations: [accountIdsOperation])
            .insertingTail(operation: mapOperation)
    }
}

// MARK: - CompoundDelegatedAccountFetchOperationFactory

extension DelegatedAccountSyncFactory: DelegatedAccountSyncFactoryProtocol {
    func createSyncWrapper(
        for chainIds: Set<ChainModel.Id>,
        metaAccountsClosure: @escaping () throws -> [ManagedMetaAccountModel]
    ) -> CompoundOperationWrapper<SyncChanges<ManagedMetaAccountModel>> {
        let discoveryWrapper = createDiscoveryWrapper(
            supportedChainIds: chainIds,
            metaAccountsClosure: metaAccountsClosure
        )

        let changesWrapper = createChangesWrapper(
            dependingOn: discoveryWrapper,
            supportedChains: chainIds,
            metaAccountsClosure: metaAccountsClosure
        )

        changesWrapper.addDependency(wrapper: discoveryWrapper)

        return changesWrapper.insertingHead(operations: discoveryWrapper.allOperations)
    }
}
