import SubstrateSdk
import Operation_iOS

protocol DelegatedAccountFetchOperationFactoryProtocol {
    func createChangesWrapper(
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
    func createWalletsWrapper(
        for filter: DelegatedAccountSyncChainWalletFilter?,
        chain: ChainModel
    ) -> CompoundOperationWrapper<[ManagedMetaAccountModel]> {
        let metaAccountsOperation = metaAccountsRepository.fetchAllOperation(with: .init())

        let filterOperation = ClosureOperation<[ManagedMetaAccountModel]> {
            let allWallets = try metaAccountsOperation.extractNoCancellableResultData()

            guard let filter else {
                return allWallets
            }

            return allWallets.filter { filter(chain, $0.info) }
        }

        filterOperation.addDependency(metaAccountsOperation)

        return CompoundOperationWrapper(targetOperation: filterOperation, dependencies: [metaAccountsOperation])
    }

    func createDelegatedAccountsListWrapper(
        metaAccountsWrapper: CompoundOperationWrapper<[ManagedMetaAccountModel]>,
        blockHash: Data?
    ) -> CompoundOperationWrapper<[AccountId: [DiscoveredDelegatedAccountProtocol]]> {
        let source = accountSourceFactory.createSource(for: blockHash)

        let accountsListWrapper: CompoundOperationWrapper<[AccountId: [DiscoveredDelegatedAccountProtocol]]>
        accountsListWrapper = OperationCombiningService.compoundNonOptionalWrapper(
            operationQueue: operationQueue
        ) { [weak self] in
            guard let self else { throw BaseOperationError.parentOperationCancelled }

            let chainMetaAccounts = try metaAccountsWrapper.targetOperation.extractNoCancellableResultData()

            let possibleDelegatorAccountsList: [AccountId] = chainMetaAccounts.compactMap { wallet in
                guard !wallet.info.isDelegated() else { return nil }

                return wallet.info.fetch(for: self.chainModel.accountRequest())?.accountId
            }

            let discoveringAccounds = DiscoveringAccountIds(
                possibleAccountIds: Set(possibleDelegatorAccountsList),
                discoveredAccounts: [:]
            )

            return createDiscoverAccountsWrapper(
                delegatedAccountsSource: source,
                discoveringAccountIds: discoveringAccounds
            )
        }

        accountsListWrapper.addDependency(wrapper: metaAccountsWrapper)

        return accountsListWrapper.insertingHead(operations: metaAccountsWrapper.allOperations)
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

            let discoveredAccountIds: Set<AccountId> = Set(
                delegatedAccounts.values
                    .flatMap { $0 }
                    .compactMap(\.accountId)
                    + delegatedAccounts.keys
            )

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
        metaAccountsWrapper: CompoundOperationWrapper<[ManagedMetaAccountModel]>,
        identityProxyFactory: IdentityProxyFactoryProtocol
    ) -> CompoundOperationWrapper<SyncChanges<ManagedMetaAccountModel>> {
        let identityWrapper = identityProxyFactory.createIdentityWrapperByAccountId(
            for: {
                let delegatedAccounts = try delegatedAccountsListWrapper
                    .targetOperation
                    .extractNoCancellableResultData()

                let delegatorIds = delegatedAccounts
                    .map(\.key)
                let delegatedIds = delegatedAccounts
                    .flatMap(\.value)
                    .compactMap(\.accountId)

                return delegatorIds + delegatedIds
            }
        )

        identityWrapper.addDependency(wrapper: delegatedAccountsListWrapper)

        let mapOperation = ClosureOperation<SyncChanges<ManagedMetaAccountModel>> { [changesCalculator] in
            let identities = try identityWrapper.targetOperation.extractNoCancellableResultData()
            let chainMetaAccounts = try metaAccountsWrapper.targetOperation.extractNoCancellableResultData()
            let remoteDelegatedAccounts = try delegatedAccountsListWrapper
                .targetOperation.extractNoCancellableResultData()

            return try changesCalculator.calculateUpdates(
                from: remoteDelegatedAccounts,
                chainMetaAccounts: chainMetaAccounts,
                identities: identities
            )
        }

        mapOperation.addDependency(identityWrapper.targetOperation)
        mapOperation.addDependency(metaAccountsWrapper.targetOperation)
        mapOperation.addDependency(delegatedAccountsListWrapper.targetOperation)

        let dependencies = delegatedAccountsListWrapper.allOperations + identityWrapper.allOperations

        return .init(targetOperation: mapOperation, dependencies: dependencies)
    }
}

// MARK: DelegatedAccountFetchOperationFactoryProtocol

extension ChainDelegatedAccountFetchOperationFactory: DelegatedAccountFetchOperationFactoryProtocol {
    func createChangesWrapper(
        at blockHash: Data?
    ) -> CompoundOperationWrapper<SyncChanges<ManagedMetaAccountModel>> {
        let metaAccountsWrapper = createWalletsWrapper(
            for: chainWalletFilter,
            chain: chainModel
        )

        let delegatedAccountsListWrapper = createDelegatedAccountsListWrapper(
            metaAccountsWrapper: metaAccountsWrapper,
            blockHash: blockHash
        )

        let changesWrapper = createChangesWrapper(
            delegatedAccountsListWrapper: delegatedAccountsListWrapper,
            metaAccountsWrapper: metaAccountsWrapper,
            identityProxyFactory: identityProxyFactory
        )

        return changesWrapper
    }
}
