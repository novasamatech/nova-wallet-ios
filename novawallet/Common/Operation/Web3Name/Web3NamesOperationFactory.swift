import Foundation
import BigInt
import RobinHood
import SubstrateSdk

protocol Web3NamesOperationFactoryProtocol {
    func searchWeb3NameWrapper(
        name: String,
        service: String,
        connection: JSONRPCEngine,
        runtimeService: RuntimeCodingServiceProtocol
    ) -> CompoundOperationWrapper<Web3NameSearchResponse?>
}

final class KiltWeb3NamesOperationFactory: Web3NamesOperationFactoryProtocol {
    private let operationQueue: OperationQueue
    private lazy var operationManager = OperationManager(operationQueue: operationQueue)

    init(operationQueue: OperationQueue) {
        self.operationQueue = operationQueue
    }

    func searchWeb3NameWrapper(
        name: String,
        service: String,
        connection: JSONRPCEngine,
        runtimeService: RuntimeCodingServiceProtocol
    ) -> CompoundOperationWrapper<Web3NameSearchResponse?> {
        let requestFactory = StorageRequestFactory(
            remoteFactory: StorageKeyFactory(),
            operationManager: operationManager
        )
        let codingFactoryOperation = runtimeService.fetchCoderFactoryOperation()

        let fetchWrapper = fetchOwnershipWrapper(
            for: name,
            dependingOn: codingFactoryOperation,
            requestFactory: requestFactory,
            connection: connection
        )

        fetchWrapper.addDependency(operations: [codingFactoryOperation])

        let searchWeb3NameWrapper = OperationCombiningService<Web3NameSearchResponse>.compoundWrapper(operationManager: operationManager) { [weak self] in
            guard let self = self,
                  let ownership = try fetchWrapper.targetOperation.extractNoCancellableResultData().first?.value else {
                return nil
            }

            let fetchServicesWrapper = self.fetchServicesWrapper(
                ownership: ownership,
                codingFactoryOperation: codingFactoryOperation,
                requestFactory: requestFactory,
                connection: connection
            )

            fetchServicesWrapper.addDependency(operations: [codingFactoryOperation])

            let mappingOperation = ClosureOperation<Web3NameSearchResponse> {
                let services = try fetchServicesWrapper.targetOperation.extractNoCancellableResultData()

                let transferAssetService = services.values.first(where: {
                    $0.serviceTypes.contains { $0.wrappedValue == service }
                })

                let urls = transferAssetService?.urls.compactMap { URL(string: $0.wrappedValue) } ?? []

                return Web3NameSearchResponse(
                    owner: ownership.owner,
                    serviceURLs: urls
                )
            }

            mappingOperation.addDependency(fetchServicesWrapper.targetOperation)
            let dependencies = fetchServicesWrapper.allOperations

            return CompoundOperationWrapper(
                targetOperation: mappingOperation,
                dependencies: dependencies
            )
        }

        let dependencies = [codingFactoryOperation] + fetchWrapper.allOperations + searchWeb3NameWrapper.dependencies
        searchWeb3NameWrapper.addDependency(wrapper: fetchWrapper)

        return .init(targetOperation: searchWeb3NameWrapper.targetOperation, dependencies: dependencies)
    }

    func fetchOwnershipWrapper(
        for name: String,
        dependingOn codingFactoryOperation: BaseOperation<RuntimeCoderFactoryProtocol>,
        requestFactory: StorageRequestFactoryProtocol,
        connection: JSONRPCEngine
    ) -> CompoundOperationWrapper<[StorageResponse<KiltW3n.Ownership>]> {
        guard let data = name.data(using: .ascii) else {
            return CompoundOperationWrapper.createWithError(CommonError.dataCorruption)
        }

        let fetchWrapper: CompoundOperationWrapper<[StorageResponse<KiltW3n.Ownership>]> = requestFactory.queryItems(
            engine: connection,
            keyParams: { [BytesCodable(wrappedValue: data)] },
            factory: { try codingFactoryOperation.extractNoCancellableResultData() },
            storagePath: KiltW3n.web3Names
        )

        return fetchWrapper
    }

    func fetchServicesWrapper(
        ownership: KiltW3n.Ownership,
        codingFactoryOperation: BaseOperation<RuntimeCoderFactoryProtocol>,
        requestFactory: StorageRequestFactoryProtocol,
        connection: JSONRPCEngine
    ) -> CompoundOperationWrapper<[KiltDid.Key: KiltDid.Endpoint]> {
        let request = MapRemoteStorageRequest(storagePath: KiltDid.endpoints) {
            ownership.owner
        }

        return requestFactory.queryByPrefix(
            engine: connection,
            request: request,
            storagePath: KiltDid.endpoints,
            factory: { try codingFactoryOperation.extractNoCancellableResultData() }
        )
    }
}

enum KnownServices {
    static let transferAssetRecipient = "KiltTransferAssetRecipientV1"
}
