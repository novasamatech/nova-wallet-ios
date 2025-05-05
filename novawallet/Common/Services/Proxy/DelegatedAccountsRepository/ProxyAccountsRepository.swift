import Foundation
import SubstrateSdk
import Operation_iOS

protocol ProxyAccountsRepositoryProtocol {
    func fetchProxiedAccountsWrapper(
        with proxyIds: Set<AccountId>
    ) -> CompoundOperationWrapper<[AccountId: [ProxyAccount]]>
}

final class ChainProxyAccountsRepository {
    private let requestFactory: StorageRequestFactoryProtocol
    private let connection: JSONRPCEngine
    private let runtimeProvider: RuntimeProviderProtocol
    private let blockHash: Data?
    
    private let operationQueue: OperationQueue
    
    private let proxyOperationFactory: ProxyOperationFactoryProtocol
    
    private var proxies: [ProxiedAccountId: [ProxyAccount]] = [:]
    
    private let mutex: NSLock = NSLock()
    
    init(
        requestFactory: StorageRequestFactoryProtocol,
        connection: JSONRPCEngine,
        runtimeProvider: RuntimeProviderProtocol,
        blockHash: Data?,
        proxyOperationFactory: ProxyOperationFactoryProtocol = ProxyOperationFactory(),
        operationQueue: OperationQueue
    ) {
        self.requestFactory = requestFactory
        self.connection = connection
        self.runtimeProvider = runtimeProvider
        self.blockHash = blockHash
        self.proxyOperationFactory = proxyOperationFactory
    }
    
    private func filterProxyList(
        _ proxyList: [ProxiedAccountId: [ProxyAccount]],
        by proxyIds: Set<AccountId>
    ) -> [ProxiedAccountId: [ProxyAccount]] {
        guard !proxyIds.isEmpty else { return proxyList }
        
        return proxyList.compactMapValues { accounts in
            accounts.filter {
                !$0.hasDelay && proxyIds.contains($0.accountId)
            }
        }.filter { !$0.value.isEmpty }
    }
}

extension ChainProxyAccountsRepository: ProxyAccountsRepositoryProtocol {
    func fetchProxiedAccountsWrapper(
        with proxyIds: Set<AccountId>
    ) -> CompoundOperationWrapper<[AccountId: [ProxyAccount]]> {
        let fetchWrapper: CompoundOperationWrapper<[AccountId: [ProxyAccount]]> = if proxies.isEmpty {
            proxyOperationFactory.fetchProxyList(
                requestFactory: requestFactory,
                connection: connection,
                runtimeProvider: runtimeProvider,
                at: blockHash
            )
        } else {
            .createWithResult(proxies)
        }
        
        let mapOperation = ClosureOperation { [weak self] in
            guard let self else { throw BaseOperationError.parentOperationCancelled }
            
            mutex.lock()
            
            defer {
                mutex.unlock()
            }
            
            proxies = try fetchWrapper.targetOperation.extractNoCancellableResultData()
            
            return filterProxyList(proxies, by: proxyIds)
        }
        
        mapOperation.addDependency(fetchWrapper.targetOperation)
        
        return fetchWrapper.insertingTail(operation: mapOperation)
    }
}
