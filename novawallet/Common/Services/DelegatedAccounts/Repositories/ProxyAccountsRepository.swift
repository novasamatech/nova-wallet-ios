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
    private var proxieds: [ProxiedAccountId: [ProxiedAccount]]

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
        _ proxiedList: [ProxiedAccountId: [ProxiedAccount]],
        by proxyIds: Set<AccountId>
    ) -> [ProxiedAccountId: [ProxiedAccount]] {
        guard !proxyIds.isEmpty else { return proxiedList }

        return proxiedList.compactMapValues { accounts in
            accounts.filter {
                !$0.proxyAccount.hasDelay && proxyIds.contains($0.accountId)
            }
        }.filter { !$0.value.isEmpty }
    }
}

// MARK: DelegatedAccountsRepositoryProtocol

extension ChainProxyAccountsRepository: DelegatedAccountsRepositoryProtocol {
    func fetchDelegatedAccountsWrapper(
        for accountIds: Set<AccountId>
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

            return self.filterProxiedList(self.proxieds, by: accountIds)
        }

        mapOperation.addDependency(fetchWrapper.targetOperation)

        return fetchWrapper.insertingTail(operation: mapOperation)
    }
}
