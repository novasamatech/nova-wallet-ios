import SubstrateSdk
import Operation_iOS

typealias ProxiedAccountId = AccountId

protocol ProxyOperationFactoryProtocol {
    func fetchProxyList(
        requestFactory: StorageRequestFactoryProtocol,
        connection: JSONRPCEngine,
        runtimeProvider: RuntimeCodingServiceProtocol,
        at blockHash: Data?
    ) -> CompoundOperationWrapper<[AccountId: [ProxiedAccount]]>
}

final class ProxyOperationFactory: ProxyOperationFactoryProtocol {
    func fetchProxyList(
        requestFactory: StorageRequestFactoryProtocol,
        connection: JSONRPCEngine,
        runtimeProvider: RuntimeCodingServiceProtocol,
        at blockHash: Data?
    ) -> CompoundOperationWrapper<[AccountId: [ProxiedAccount]]> {
        let request = UnkeyedRemoteStorageRequest(storagePath: Proxy.proxyList)
        let codingFactoryOperation = runtimeProvider.fetchCoderFactoryOperation()

        let options = StorageQueryListOptions(
            atBlock: blockHash,
            ignoresFailedItems: true
        )
        let fetchWrapper: CompoundOperationWrapper<[AccountIdKey: ProxyDefinition]> =
            requestFactory.queryByPrefix(
                engine: connection,
                request: request,
                storagePath: Proxy.proxyList,
                factory: { try codingFactoryOperation.extractNoCancellableResultData() },
                options: options
            )

        let mapper = ClosureOperation<[AccountId: [ProxiedAccount]]> {
            let proxyResult = try fetchWrapper.targetOperation.extractNoCancellableResultData()

            return proxyResult.reduce(into: [AccountId: [ProxiedAccount]]()) { result, nextPart in
                let proxies = nextPart.value.definition.map {
                    ProxyAccount(
                        accountId: $0.proxy,
                        type: $0.proxyType,
                        delay: $0.delay
                    )
                }

                proxies.forEach { proxy in
                    let proxied = ProxiedAccount(
                        accountId: nextPart.key.accountId,
                        proxyAccount: proxy
                    )
                    if let currentProxieds = result[proxy.accountId] {
                        result[proxy.accountId] = currentProxieds + [proxied]
                    } else {
                        result[proxy.accountId] = [proxied]
                    }
                }
            }
        }
        fetchWrapper.addDependency(operations: [codingFactoryOperation])
        mapper.addDependency(fetchWrapper.targetOperation)

        let dependencies = [codingFactoryOperation] + fetchWrapper.allOperations

        return .init(targetOperation: mapper, dependencies: dependencies)
    }
}
