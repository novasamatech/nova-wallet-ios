import SubstrateSdk
import Operation_iOS

protocol DelegatedAccountFetchOperationFactoryProtocol {
    func createChangesWrapper(
        metaAccountsClosure: @escaping () throws -> [ManagedMetaAccountModel],
        at blockHash: Data?
    ) -> CompoundOperationWrapper<SyncChanges<ManagedMetaAccountModel>>
}

private struct DiscoveringAccountIds {
    let possibleAccountIds: Set<AccountId>
    let discoveredAccounts: [AccountId: [DiscoveredDelegatedAccountProtocol]]
}

final class ChainDelegatedAccountFetchOperationFactory {
    let metaAccountsRepository: AnyDataProviderRepository<ManagedMetaAccountModel>
    let chainRegistry: ChainRegistryProtocol
    let chainModel: ChainModel
    let accountSourceFactory: DelegatedAccountSourceFactoryProtocol
    let requestFactory: StorageRequestFactoryProtocol
    let identityProxyFactory: IdentityProxyFactoryProtocol
    let chainWalletFilter: DelegatedAccountSyncChainWalletFilter?

    private let operationQueue: OperationQueue
    private let changesCalculator: DelegatedAccountsChangesCalcualtorProtocol

    init(
        chainModel: ChainModel,
        metaAccountsRepository: AnyDataProviderRepository<ManagedMetaAccountModel>,
        chainRegistry: ChainRegistryProtocol,
        operationQueue: OperationQueue,
        chainWalletFilter: DelegatedAccountSyncChainWalletFilter?
    ) {
        self.chainModel = chainModel
        self.chainRegistry = chainRegistry
        self.operationQueue = operationQueue
        self.metaAccountsRepository = metaAccountsRepository
        self.chainWalletFilter = chainWalletFilter
        changesCalculator = DelegatedAccountsChangesCalculator(chainModel: chainModel)
        requestFactory = StorageRequestFactory(
            remoteFactory: StorageKeyFactory(),
            operationManager: OperationManager(operationQueue: operationQueue)
        )
        accountSourceFactory = DelegatedAccountSourceFactory(
            chain: chainModel,
            chainRegistry: chainRegistry,
            requestFactory: requestFactory,
            operationQueue: operationQueue
        )

        let identityOperationFactory = IdentityOperationFactory(requestFactory: requestFactory)
        identityProxyFactory = IdentityProxyFactory(
            originChain: chainModel,
            chainRegistry: chainRegistry,
            identityOperationFactory: identityOperationFactory
        )
    }
}

// MARK: Private

private extension ChainDelegatedAccountFetchOperationFactory {
    func createDelegatedAccountsListWrapper(
        metaAccountsClosure: @escaping () throws -> [ManagedMetaAccountModel],
        blockHash: Data?
    ) -> CompoundOperationWrapper<[AccountId: [DiscoveredDelegatedAccountProtocol]]> {
        let source = accountSourceFactory.createSource(for: blockHash)

        let accountsListWrapper: CompoundOperationWrapper<[AccountId: [DiscoveredDelegatedAccountProtocol]]>
        accountsListWrapper = OperationCombiningService.compoundNonOptionalWrapper(
            operationQueue: operationQueue
        ) { [weak self] in
            guard let self else { throw BaseOperationError.parentOperationCancelled }

            let metaAccounts = try metaAccountsClosure()

            let possibleDelegatorAccountsList: [AccountId] = metaAccounts.compactMap { wallet in
                guard !wallet.info.isDelegated() else { return nil }

                return wallet.info.fetch(for: self.chainModel.accountRequest())?.accountId
            }

            let discoveringAccountIds = DiscoveringAccountIds(
                possibleAccountIds: Set(possibleDelegatorAccountsList),
                discoveredAccounts: [:]
            )

            return createDiscoverAccountsWrapper(
                delegatedAccountsSource: source,
                discoveringAccountIds: discoveringAccountIds
            )
        }

        return accountsListWrapper
    }

    func createDiscoverAccountsWrapper(
        delegatedAccountsSource: DelegatedAccountsRepositoryProtocol,
        discoveringAccountIds: DiscoveringAccountIds
    ) -> CompoundOperationWrapper<[AccountId: [DiscoveredDelegatedAccountProtocol]]> {
        let accountsFetchWrapper = delegatedAccountsSource.fetchDelegatedAccountsWrapper(
            for: discoveringAccountIds.possibleAccountIds
        )

        let resultWrapper: CompoundOperationWrapper<[AccountId: [DiscoveredDelegatedAccountProtocol]]>
        resultWrapper = OperationCombiningService.compoundNonOptionalWrapper(
            operationQueue: operationQueue
        ) { [weak self] in
            guard let self else { throw BaseOperationError.parentOperationCancelled }

            let delegatedAccounts = try accountsFetchWrapper
                .targetOperation
                .extractNoCancellableResultData()

            let discoveredAccountIds: Set<AccountId> = delegatedAccounts
                .values
                .reduce(into: []) { acc, accounts in
                    accounts.forEach {
                        acc.insert($0.accountId)
                        acc.insert($0.delegateAccountId)
                    }
                }

            let updatedDiscoveringIds = DiscoveringAccountIds(
                possibleAccountIds: discoveringAccountIds.possibleAccountIds.union(discoveredAccountIds),
                discoveredAccounts: delegatedAccounts
            )

            guard updatedDiscoveringIds.possibleAccountIds != discoveringAccountIds.possibleAccountIds else {
                return .createWithResult(updatedDiscoveringIds.discoveredAccounts)
            }

            return createDiscoverAccountsWrapper(
                delegatedAccountsSource: delegatedAccountsSource,
                discoveringAccountIds: updatedDiscoveringIds
            )
        }

        resultWrapper.addDependency(wrapper: accountsFetchWrapper)

        return resultWrapper.insertingHead(operations: accountsFetchWrapper.allOperations)
    }

    func createChangesWrapper(
        delegatedAccountsListWrapper: CompoundOperationWrapper<[AccountId: [DiscoveredDelegatedAccountProtocol]]>,
        metaAccountsClosure: @escaping () throws -> [ManagedMetaAccountModel],
        identityProxyFactory: IdentityProxyFactoryProtocol
    ) -> CompoundOperationWrapper<SyncChanges<ManagedMetaAccountModel>> {
        let identityWrapper = identityProxyFactory.createIdentityWrapperByAccountId(
            for: {
                let discoveredAccounts = try delegatedAccountsListWrapper
                    .targetOperation
                    .extractNoCancellableResultData()

                let allDiscoveredIds = discoveredAccounts
                    .values
                    .reduce(into: Set<AccountId>()) { acc, accounts in
                        accounts.forEach {
                            acc.insert($0.accountId)
                            acc.insert($0.delegateAccountId)
                        }
                    }

                return Array(allDiscoveredIds)
            }
        )

        identityWrapper.addDependency(wrapper: delegatedAccountsListWrapper)

        let mapOperation = ClosureOperation<SyncChanges<ManagedMetaAccountModel>> { [changesCalculator] in
            let metaAccounts = try metaAccountsClosure()
            let identities = try identityWrapper.targetOperation.extractNoCancellableResultData()
            let remoteDelegatedAccounts = try delegatedAccountsListWrapper
                .targetOperation
                .extractNoCancellableResultData()

            return try changesCalculator.calculateUpdates(
                from: remoteDelegatedAccounts,
                chainMetaAccounts: metaAccounts,
                identities: identities
            )
        }

        mapOperation.addDependency(identityWrapper.targetOperation)
        mapOperation.addDependency(delegatedAccountsListWrapper.targetOperation)

        let dependencies = delegatedAccountsListWrapper.allOperations + identityWrapper.allOperations

        return .init(targetOperation: mapOperation, dependencies: dependencies)
    }
}

// MARK: DelegatedAccountFetchOperationFactoryProtocol

extension ChainDelegatedAccountFetchOperationFactory: DelegatedAccountFetchOperationFactoryProtocol {
    func createChangesWrapper(
        metaAccountsClosure: @escaping () throws -> [ManagedMetaAccountModel],
        at blockHash: Data?
    ) -> CompoundOperationWrapper<SyncChanges<ManagedMetaAccountModel>> {
        let delegatedAccountsListWrapper = createDelegatedAccountsListWrapper(
            metaAccountsClosure: metaAccountsClosure,
            blockHash: blockHash
        )

        let changesWrapper = createChangesWrapper(
            delegatedAccountsListWrapper: delegatedAccountsListWrapper,
            metaAccountsClosure: metaAccountsClosure,
            identityProxyFactory: identityProxyFactory
        )

        return changesWrapper
    }
}
