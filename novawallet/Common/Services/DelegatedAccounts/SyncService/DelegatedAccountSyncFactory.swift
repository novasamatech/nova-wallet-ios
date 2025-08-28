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
    ) -> CompoundOperationWrapper<DelegatedAccountsByDelegate> {
        let accountsListWrapper = OperationCombiningService<DelegatedAccountsByDelegate>.compoundNonOptionalWrapper(
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
        dependingOn discoveryWrapper: CompoundOperationWrapper<DelegatedAccountsByDelegate>,
        supportedChains: Set<ChainModel.Id>,
        metaAccountsClosure: @escaping () throws -> [ManagedMetaAccountModel]
    ) -> CompoundOperationWrapper<[SyncChanges<ManagedMetaAccountModel>]> {
        let accountIdsOperation = ClosureOperation<[AccountId]> {
            Array(
                try discoveryWrapper
                    .targetOperation
                    .extractNoCancellableResultData()
                    .flatMap(\.accounts)
                    .reduce(into: Set<AccountId>()) {
                        $0.insert($1.accountId)
                        $0.insert($1.delegateAccountId)
                    }
            )
        }

        let identityWrapper = identityFactory.createIdentityWrapperByAccountId(
            for: {
                try accountIdsOperation.extractNoCancellableResultData()
            }
        )

        identityWrapper.addDependency(operations: [accountIdsOperation])

        let mapOperation = ClosureOperation<[SyncChanges<ManagedMetaAccountModel>]> { [chainRegistry, logger] in
            let metaAccounts = try metaAccountsClosure()
            let identities = try identityWrapper.targetOperation.extractNoCancellableResultData()
            let remoteAccounts = try discoveryWrapper.targetOperation.extractNoCancellableResultData()

            self.logger.debug("Discovered accounts: \(remoteAccounts.count)")
            self.logger.debug("Discovered identities: \(identities.count)")

            return try DelegatedAccountsChangesFacade(
                chainRegistry: chainRegistry,
                logger: logger
            ).calculateUpdates(
                from: remoteAccounts,
                supportedChains: supportedChains,
                chainMetaAccounts: metaAccounts,
                identities: identities
            )
        }

        mapOperation.addDependency(identityWrapper.targetOperation)

        return identityWrapper
            .insertingHead(operations: [accountIdsOperation])
            .insertingTail(operation: mapOperation)
    }

    func createMergeChangesOperation(
        dependingOn changesOperation: BaseOperation<[SyncChanges<ManagedMetaAccountModel>]>
    ) -> BaseOperation<SyncChanges<ManagedMetaAccountModel>> {
        ClosureOperation {
            let changes = try changesOperation.extractNoCancellableResultData()
            let delegateStatusMap: [MetaAccountDelegationId: (Set<DelegatedAccount.Status>, ManagedMetaAccountModel)]

            delegateStatusMap = changes
                .flatMap(\.newOrUpdatedItems)
                .reduce(into: [:]) { acc, managedMetaAccount in
                    guard
                        let delegationId = managedMetaAccount.info.delegationId,
                        let status = managedMetaAccount.info.delegatedAccountStatus()
                    else { return }

                    if acc[delegationId] == nil {
                        acc[delegationId] = ([status], managedMetaAccount)
                    } else {
                        acc[delegationId]?.0.insert(status)
                    }
                }

            let resultUpdates = delegateStatusMap.map { delegationId, value in
                let collectedStatuses = value.0
                let managedMetaAccount = value.1

                guard
                    collectedStatuses.count > 1,
                    let currentStatus = managedMetaAccount.info.delegatedAccountStatus()
                else { return managedMetaAccount }

                // We don't want to overwrite revoke status for chain-specific delegation
                // since the only revoke status comes for the delegation's chain

                let chainSpecificRevoke = delegationId.chainId != nil && collectedStatuses.contains(.revoked)

                let resultStatus: DelegatedAccount.Status = if chainSpecificRevoke {
                    .revoked
                } else if collectedStatuses.contains(.new) {
                    .new
                } else if collectedStatuses.contains(.active) {
                    .active
                } else {
                    .revoked
                }

                return managedMetaAccount.replacingInfo(
                    managedMetaAccount.info.replacingDelegatedAccountStatus(
                        from: currentStatus,
                        to: resultStatus
                    )
                )
            }

            return SyncChanges(
                newOrUpdatedItems: resultUpdates,
                removedItems: changes.flatMap(\.removedItems)
            )
        }
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

        let mergeOperation = createMergeChangesOperation(dependingOn: changesWrapper.targetOperation)

        mergeOperation.addDependency(changesWrapper.targetOperation)

        return changesWrapper
            .insertingHead(operations: discoveryWrapper.allOperations)
            .insertingTail(operation: mergeOperation)
    }
}
