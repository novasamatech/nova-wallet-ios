import SubstrateSdk
import RobinHood

typealias ProxiedAccountId = AccountId

protocol ProxyOperationFactoryProtocol {
    func fetchProxyList(
        requestFactory: StorageRequestFactoryProtocol,
        connection: JSONRPCEngine,
        runtimeProvider: RuntimeCodingServiceProtocol
    ) -> CompoundOperationWrapper<[ProxiedAccountId: [ProxyAccount]]>
}

final class ProxyOperationFactory: ProxyOperationFactoryProtocol {
    func fetchProxyList(
        requestFactory: StorageRequestFactoryProtocol,
        connection: JSONRPCEngine,
        runtimeProvider: RuntimeCodingServiceProtocol
    ) -> CompoundOperationWrapper<[ProxiedAccountId: [ProxyAccount]]> {
        let request = UnkeyedRemoteStorageRequest(storagePath: Proxy.proxyList)
        let codingFactoryOperation = runtimeProvider.fetchCoderFactoryOperation()

        let options = StorageQueryListOptions(ignoresFailedItems: true)
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
                    ProxyAccount(accountId: $0.delegate, type: $0.proxyType)
                }
            }
        }
        fetchWrapper.addDependency(operations: [codingFactoryOperation])
        mapper.addDependency(fetchWrapper.targetOperation)

        let dependencies = [codingFactoryOperation] + fetchWrapper.allOperations

        return .init(targetOperation: mapper, dependencies: dependencies)
    }
}
