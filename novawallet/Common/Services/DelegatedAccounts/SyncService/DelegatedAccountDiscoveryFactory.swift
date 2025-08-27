import Foundation
import Operation_iOS

protocol DelegatedAccountDiscoveryFactoryProtocol {
    func createDiscoveryWrapper(
        startingFrom accountIds: Set<AccountId>
    ) -> CompoundOperationWrapper<DelegatedAccountsByDelegate>
}

final class DelegatedAccountDiscoveryFactory {
    struct PartialDiscovery {
        let possibleAccountIds: Set<AccountId>
        let discoveredAccounts: DelegatedAccountsByDelegate
    }

    let remoteSource: DelegatedAccountsAggregatorProtocol
    let operationQueue: OperationQueue

    init(
        remoteSource: DelegatedAccountsAggregatorProtocol,
        operationQueue: OperationQueue
    ) {
        self.remoteSource = remoteSource
        self.operationQueue = operationQueue
    }
}

private extension DelegatedAccountDiscoveryFactory {
    func createDiscoverAccountsWrapper(
        partialDiscovery: PartialDiscovery,
        discoveryQueue: Set<AccountId>
    ) -> CompoundOperationWrapper<DelegatedAccountsByDelegate> {
        let accountsFetchWrapper = remoteSource.fetchDelegatedAccountsWrapper(
            for: discoveryQueue
        )

        let resultWrapper: CompoundOperationWrapper<DelegatedAccountsByDelegate>
        resultWrapper = OperationCombiningService.compoundNonOptionalWrapper(
            operationQueue: operationQueue
        ) {
            let delegatedAccounts = try accountsFetchWrapper
                .targetOperation
                .extractNoCancellableResultData()

            let newPossibleAccountIds: Set<AccountId> = delegatedAccounts
                .flatMap(\.accounts)
                .reduce(into: partialDiscovery.possibleAccountIds) { $0.insert($1.accountId) }

            let newDiscoveredAccounts = partialDiscovery.discoveredAccounts + delegatedAccounts

            let nextDiscoveryQueue = newPossibleAccountIds.subtracting(partialDiscovery.possibleAccountIds)

            guard !nextDiscoveryQueue.isEmpty else {
                return .createWithResult(newDiscoveredAccounts)
            }

            return self.createDiscoverAccountsWrapper(
                partialDiscovery: PartialDiscovery(
                    possibleAccountIds: newPossibleAccountIds,
                    discoveredAccounts: newDiscoveredAccounts
                ),
                discoveryQueue: nextDiscoveryQueue
            )
        }

        resultWrapper.addDependency(wrapper: accountsFetchWrapper)

        return resultWrapper.insertingHead(operations: accountsFetchWrapper.allOperations)
    }
}

extension DelegatedAccountDiscoveryFactory: DelegatedAccountDiscoveryFactoryProtocol {
    func createDiscoveryWrapper(
        startingFrom accountIds: Set<AccountId>
    ) -> CompoundOperationWrapper<DelegatedAccountsByDelegate> {
        createDiscoverAccountsWrapper(
            partialDiscovery: PartialDiscovery(
                possibleAccountIds: accountIds,
                discoveredAccounts: []
            ),
            discoveryQueue: accountIds
        )
    }
}
