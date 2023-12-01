final class ProxyOperationFactory {
    func fetchProxyList(
        requestFactory: StorageRequestFactoryProtocol,
        connection: JSONRPCEngine,
        runtimeProvider: RuntimeCodingServiceProtocol
    ) -> CompoundOperationWrapper<[AccountId: [ProxyAccounts]]> {
        let request = UnkeyedRemoteStorageRequest(storagePath: Proxy.proxyList)
        let codingFactoryOperation = runtimeProvider.fetchCoderFactoryOperation()

        let fetchWrapper: CompoundOperationWrapper<[AccountIdKey: ProxyDefinition]> =
            requestFactory.queryByPrefix(
                engine: connection,
                request: request,
                storagePath: Proxy.proxyList,
                factory: { try codingFactoryOperation.extractNoCancellableResultData() }
            )

        let mapper = ClosureOperation<[AccountId: [ProxyAccounts]]> {
            let proxyResult = try fetchWrapper.targetOperation.extractNoCancellableResultData()
            return proxyResult.map { key, value in
                (key.accountId, value.definition.map { ProxyAccounts(accountId: $0.delegate, role: $0.proxyType) })
            }
        }
        fetchWrapper.addDependency(operations: [codingFactoryOperation])
        mapper.addDependency(fetchWrapper.targetOperation)

        let dependencies = [codingFactoryOperation] + fetchWrapper.allOperations

        return .init(targetOperation: mapper, dependencies: dependencies)
    }
}

public extension Dictionary {
    func map<T: Hashable, U>(transform: (Key, Value) -> (T, U)) -> [T: U] {
        var result: [T: U] = [:]
        for (key, value) in self {
            let (transformedKey, transformedValue) = transform(key, value)
            result[transformedKey] = transformedValue
        }
        return result
    }
}
