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
            operationManager: OperationManager(operationQueue: operationQueue)
        )
        let codingFactoryOperation = runtimeService.fetchCoderFactoryOperation()

        let fetchWrapper = fetchOwnershipWrapper(
            for: name,
            dependingOn: codingFactoryOperation,
            requestFactory: requestFactory,
            connection: connection
        )

        let services = fetchServicesWrapper(
            dependingOn: fetchWrapper.targetOperation,
            codingFactoryOperation: codingFactoryOperation,
            requestFactory: requestFactory,
            connection: connection
        )

        services.addDependency(operations: [codingFactoryOperation, fetchWrapper.targetOperation])

        let mappingOperation = ClosureOperation<Web3NameSearchResponse?> {
            guard let ownership = try fetchWrapper.targetOperation.extractNoCancellableResultData() else {
                return nil
            }

            let services = try services.targetOperation.extractNoCancellableResultData()
            let transferAssetService = services.values.first(where: { $0.serviceTypes.contains(service) })
            let url = transferAssetService?.urls.first.map { URL(string: $0) } ?? nil

            return Web3NameSearchResponse(
                owner: ownership.owner,
                serviceURL: url
            )
        }

        let dependencies = fetchWrapper.allOperations + services.allOperations

        dependencies.forEach { mappingOperation.addDependency($0) }

        return CompoundOperationWrapper(targetOperation: mappingOperation, dependencies: dependencies)
    }

    private func fetchOwnershipWrapper(
        for name: String,
        dependingOn codingFactoryOperation: BaseOperation<RuntimeCoderFactoryProtocol>,
        requestFactory: StorageRequestFactoryProtocol,
        connection: JSONRPCEngine
    ) -> CompoundOperationWrapper<Web3NameOwnership?> {
        guard let data = name.data(using: .utf8) else {
            return CompoundOperationWrapper.createWithError(CommonError.dataCorruption)
        }

        let fetchWrapper: CompoundOperationWrapper<[StorageResponse<Web3NameOwnership>]> = requestFactory.queryItems(
            engine: connection,
            keyParams: { [BytesCodable(wrappedValue: data)] },
            factory: { try codingFactoryOperation.extractNoCancellableResultData() },
            storagePath: StorageCodingPath.web3Names
        )

        fetchWrapper.addDependency(operations: [codingFactoryOperation])

        let mappingOperation = ClosureOperation<Web3NameOwnership?> {
            guard let ownership = try fetchWrapper.targetOperation.extractNoCancellableResultData().first?.value else {
                return nil
            }

            return ownership
        }

        let dependencies = [codingFactoryOperation] + fetchWrapper.allOperations

        dependencies.forEach { mappingOperation.addDependency($0) }

        return .init(targetOperation: mappingOperation, dependencies: dependencies)
    }

    private func fetchServicesWrapper(
        dependingOn ownershipOperation: BaseOperation<Web3NameOwnership?>,
        codingFactoryOperation: BaseOperation<RuntimeCoderFactoryProtocol>,
        requestFactory: StorageRequestFactoryProtocol,
        connection: JSONRPCEngine
    ) -> CompoundOperationWrapper<[DigitalIdentifierService.Key: DigitalIdentifierService.Endpoint]> {
        let request = MapRemoteStorageRequest(storagePath: StorageCodingPath.digitalIdentityEndpoints) {
            let ownership = try ownershipOperation.extractNoCancellableResultData()
            guard let owner = ownership?.owner else {
                throw CommonError.dataCorruption
            }
            return owner
        }

        return requestFactory.queryByPrefix(
            engine: connection,
            request: request,
            storagePath: StorageCodingPath.digitalIdentityEndpoints,
            factory: { try codingFactoryOperation.extractNoCancellableResultData() }
        )
    }
}

enum KnownServices {
    static let transferAssetRecipient = "KiltTransferAssetRecipientV1"
}
