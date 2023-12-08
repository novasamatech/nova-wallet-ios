import SubstrateSdk
import RobinHood
import Foundation

protocol ProxyOperationFactoryProtocol {
    func fetchProxyList(
        requestFactory: StorageRequestFactoryProtocol,
        connection: JSONRPCEngine,
        runtimeProvider: RuntimeCodingServiceProtocol
    ) -> CompoundOperationWrapper<[AccountId: [ProxiedAccount]]>
}

final class ProxyOperationFactory: ProxyOperationFactoryProtocol {
    func fetchProxyList(
        requestFactory: StorageRequestFactoryProtocol,
        connection: JSONRPCEngine,
        runtimeProvider: RuntimeCodingServiceProtocol
    ) -> CompoundOperationWrapper<[AccountId: [ProxiedAccount]]> {
        let request = UnkeyedRemoteStorageRequest(storagePath: Proxy.proxyList)
        let codingFactoryOperation = runtimeProvider.fetchCoderFactoryOperation()

        let fetchWrapper: CompoundOperationWrapper<[AccountIdKey: ProxyDefinition]> =
            requestFactory.queryByPrefix(
                engine: connection,
                request: request,
                storagePath: Proxy.proxyList,
                factory: { try codingFactoryOperation.extractNoCancellableResultData() }
            )

        let mapper = ClosureOperation<[AccountId: [ProxiedAccount]]> {
            let proxyResult = try fetchWrapper.targetOperation.extractNoCancellableResultData()

            return proxyResult.reduce(into: [AccountId: [ProxiedAccount]]()) { result, nextPart in
                nextPart.value.definition.forEach { proxy in
                    guard proxy.delay == 0 else {
                        return
                    }
                    let newProxied = ProxiedAccount(accountId: nextPart.key.accountId, type: proxy.proxyType)
                    if let delegate = result[proxy.delegate], !delegate.contains(element: newProxied) {
                        result[proxy.delegate]?.append(newProxied)
                    } else {
                        result[proxy.delegate] = [newProxied]
                    }
                }
            }
        }
        fetchWrapper.addDependency(operations: [codingFactoryOperation])
        fetchWrapper.allOperations.forEach {
            mapper.addDependency($0)
        }
        let dependencies = [codingFactoryOperation] + fetchWrapper.allOperations

        return .init(targetOperation: mapper, dependencies: dependencies)
    }
}

extension Array where Element: Equatable {
    func contains(element: Element) -> Bool {
        firstIndex(where: { $0 == element }) != nil
    }
}
