import Foundation
import SubstrateSdk
import Operation_iOS

final class ChainProxyAccountsRepository {
    private let requestFactory: StorageRequestFactoryProtocol
    private let connection: JSONRPCEngine
    private let runtimeProvider: RuntimeProviderProtocol
    private let blockHash: Data?

    private let proxyOperationFactory: ProxyOperationFactoryProtocol

    @Atomic(defaultValue: [:])
    private var proxieds: [AccountId: [ProxiedAccount]]

    private let mutex = NSLock()

    init(
        requestFactory: StorageRequestFactoryProtocol,
        connection: JSONRPCEngine,
        runtimeProvider: RuntimeProviderProtocol,
        blockHash: Data?,
        proxyOperationFactory: ProxyOperationFactoryProtocol = ProxyOperationFactory()
    ) {
        self.requestFactory = requestFactory
        self.connection = connection
        self.runtimeProvider = runtimeProvider
        self.blockHash = blockHash
        self.proxyOperationFactory = proxyOperationFactory
    }

    private func filterProxiedList(
        _ proxiedList: [AccountId: [ProxiedAccount]],
        by proxyIds: Set<AccountId>
    ) -> [AccountId: [ProxiedAccount]] {
        guard !proxyIds.isEmpty else { return [:] }

        return proxyIds
            .reduce(into: [:]) { acc, id in
                acc[id] = proxiedList[id]?.filter {
                    !$0.proxyAccount.hasDelay && proxyIds.contains($0.proxyAccount.accountId)
                }
            }
            .filter { !$0.value.isEmpty }
    }
}

// MARK: DelegatedAccountsRepositoryProtocol

extension ChainProxyAccountsRepository: DelegatedAccountsRepositoryProtocol {
    func fetchDelegatedAccountsWrapper(
        for proxyIds: Set<AccountId>
    ) -> CompoundOperationWrapper<[AccountId: [DiscoveredDelegatedAccountProtocol]]> {
        let fetchWrapper: CompoundOperationWrapper<[AccountId: [ProxiedAccount]]> = if proxieds.isEmpty {
            proxyOperationFactory.fetchProxyList(
                requestFactory: requestFactory,
                connection: connection,
                runtimeProvider: runtimeProvider,
                at: blockHash
            )
        } else {
            .createWithResult(proxieds)
        }

        let mapOperation = ClosureOperation<[AccountId: [DiscoveredDelegatedAccountProtocol]]> {
            self.proxieds = try fetchWrapper.targetOperation.extractNoCancellableResultData()

            return self.filterProxiedList(self.proxieds, by: proxyIds)
        }

        mapOperation.addDependency(fetchWrapper.targetOperation)

        return fetchWrapper.insertingTail(operation: mapOperation)
    }
}
