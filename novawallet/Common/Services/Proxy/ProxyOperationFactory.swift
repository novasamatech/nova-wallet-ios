import SubstrateSdk
import Operation_iOS

typealias ProxiedAccountId = AccountId

protocol ProxyOperationFactoryProtocol {
    func fetchProxyList(
        requestFactory: StorageRequestFactoryProtocol,
        connection: JSONRPCEngine,
        runtimeProvider: RuntimeCodingServiceProtocol,
        at blockHash: Data?
    ) -> CompoundOperationWrapper<[ProxiedAccountId: [ProxyAccount]]>
}

final class ProxyOperationFactory: ProxyOperationFactoryProtocol {
    func fetchProxyList(
        requestFactory: StorageRequestFactoryProtocol,
        connection: JSONRPCEngine,
        runtimeProvider: RuntimeCodingServiceProtocol,
        at blockHash: Data?
    ) -> CompoundOperationWrapper<[ProxiedAccountId: [ProxyAccount]]> {
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

        let mapper = ClosureOperation<[ProxiedAccountId: [ProxyAccount]]> {
            let proxyResult = try fetchWrapper.targetOperation.extractNoCancellableResultData()
            return proxyResult.reduce(into: [AccountId: [ProxyAccount]]()) { result, nextPart in
                result[nextPart.key.accountId] = nextPart.value.definition.map {
                    ProxyAccount(accountId: $0.proxy, type: $0.proxyType, delay: $0.delay)
                }
            }
        }
        fetchWrapper.addDependency(operations: [codingFactoryOperation])
        mapper.addDependency(fetchWrapper.targetOperation)

        let dependencies = [codingFactoryOperation] + fetchWrapper.allOperations

        return .init(targetOperation: mapper, dependencies: dependencies)
    }
}
