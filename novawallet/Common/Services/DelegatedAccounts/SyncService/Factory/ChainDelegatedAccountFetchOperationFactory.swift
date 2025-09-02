import SubstrateSdk
import Operation_iOS

protocol DelegatedAccountFetchOperationFactoryProtocol {
    func createChangesWrapper(
        metaAccountsClosure: @escaping () throws -> [ManagedMetaAccountModel],
        at blockHash: Data?
    ) -> CompoundOperationWrapper<SyncChanges<ManagedMetaAccountModel>>
}

private struct DiscoveringAccountIds {
    let possibleAccountIds: [AccountId]
    let discoveredAccounts: DelegatedAccountsByDelegate
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
    ) -> CompoundOperationWrapper<DelegatedAccountsByDelegate> {
        let source = accountSourceFactory.createSource(for: blockHash)

        let accountsListWrapper: CompoundOperationWrapper<DelegatedAccountsByDelegate>
        accountsListWrapper = OperationCombiningService.compoundNonOptionalWrapper(
            operationQueue: operationQueue
        ) {
            let metaAccounts = try metaAccountsClosure()

            let possibleDelegateAccountsList: [AccountId] = metaAccounts.compactMap { wallet in
                guard !wallet.info.isDelegated() else { return nil }

                return wallet.info.fetch(for: self.chainModel.accountRequest())?.accountId
            }

            let discoveringAccountIds = DiscoveringAccountIds(
                possibleAccountIds: possibleDelegateAccountsList,
                discoveredAccounts: []
            )

            return self.createDiscoverAccountsWrapper(
                delegatedAccountsSource: source,
                discoveringAccountIds: discoveringAccountIds
            )
        }

        return accountsListWrapper
    }

    func createDiscoverAccountsWrapper(
        delegatedAccountsSource: DelegatedAccountsAggregatorProtocol,
        discoveringAccountIds: DiscoveringAccountIds
    ) -> CompoundOperationWrapper<DelegatedAccountsByDelegate> {
        let accountsFetchWrapper = delegatedAccountsSource.fetchDelegatedAccountsWrapper(
            for: discoveringAccountIds.possibleAccountIds
        )

        let resultWrapper: CompoundOperationWrapper<DelegatedAccountsByDelegate>
        resultWrapper = OperationCombiningService.compoundNonOptionalWrapper(
            operationQueue: operationQueue
        ) { [weak self] in
            guard let self else { throw BaseOperationError.parentOperationCancelled }

            let delegatedAccounts = try accountsFetchWrapper
                .targetOperation
                .extractNoCancellableResultData()

            var discoveredAccountIds: [AccountId] = discoveringAccountIds.possibleAccountIds
            var checkedAccountIds: Set<AccountId> = Set(discoveredAccountIds)

            delegatedAccounts
                .flatMap(\.accounts)
                .forEach { account in
                    if !checkedAccountIds.contains(account.accountId) {
                        checkedAccountIds.insert(account.accountId)
                        discoveredAccountIds.append(account.accountId)
                    }
                }

            let updatedDiscoveringIds = DiscoveringAccountIds(
                possibleAccountIds: discoveredAccountIds,
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
        delegatedAccountsListWrapper: CompoundOperationWrapper<DelegatedAccountsByDelegate>,
        metaAccountsClosure: @escaping () throws -> [ManagedMetaAccountModel],
        identityProxyFactory: IdentityProxyFactoryProtocol
    ) -> CompoundOperationWrapper<SyncChanges<ManagedMetaAccountModel>> {
        let identityWrapper = identityProxyFactory.createIdentityWrapperByAccountId(
            for: {
                Array(
                    try delegatedAccountsListWrapper
                        .targetOperation
                        .extractNoCancellableResultData()
                        .flatMap(\.accounts)
                        .reduce(into: Set<AccountId>()) {
                            $0.insert($1.accountId)
                            $0.insert($1.delegateAccountId)
                        }
                )
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
