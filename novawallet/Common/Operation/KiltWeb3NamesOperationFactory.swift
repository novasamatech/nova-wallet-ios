import Foundation
import BigInt
import RobinHood
import SubstrateSdk

protocol KiltWeb3NamesOperationFactoryProtocol {
    func createOwnerOperation(
        name: String,
        connection: JSONRPCEngine,
        runtimeService: RuntimeCodingServiceProtocol
    ) -> CompoundOperationWrapper<Web3NamesOwnership?>
}

final class KiltWeb3NamesOperationFactory: KiltWeb3NamesOperationFactoryProtocol {
    private let operationQueue: OperationQueue

    init(operationQueue: OperationQueue) {
        self.operationQueue = operationQueue
    }

    func createOwnerOperation(
        name: String,
        connection: JSONRPCEngine,
        runtimeService: RuntimeCodingServiceProtocol
    ) -> CompoundOperationWrapper<Web3NamesOwnership?> {
        guard let data = name.data(using: .utf8) else {
            return CompoundOperationWrapper.createWithError(CommonError.dataCorruption)
        }
        let requestFactory = StorageRequestFactory(
            remoteFactory: StorageKeyFactory(),
            operationManager: OperationManager(operationQueue: operationQueue)
        )
        let codingFactoryOperation = runtimeService.fetchCoderFactoryOperation()

        let fetchWrapper: CompoundOperationWrapper<[StorageResponse<Web3NamesOwnership>]> = requestFactory.queryItems(
            engine: connection,
            keyParams: { [BytesCodable(wrappedValue: data)] },
            factory: { try codingFactoryOperation.extractNoCancellableResultData() },
            storagePath: StorageCodingPath.kiltName
        )

        fetchWrapper.addDependency(operations: [codingFactoryOperation])

        let mappingOperation = ClosureOperation<Web3NamesOwnership?> {
            guard let ownership = try fetchWrapper.targetOperation.extractNoCancellableResultData().first?.value else {
                return nil
            }
            return ownership
        }

        let dependencies = [codingFactoryOperation] + fetchWrapper.allOperations

        dependencies.forEach { mappingOperation.addDependency($0) }

        return CompoundOperationWrapper(targetOperation: mappingOperation, dependencies: dependencies)
    }

    func createServicesOperation(
        owner: AccountId,
        connection: JSONRPCEngine,
        runtimeService: RuntimeCodingServiceProtocol
    ) -> CompoundOperationWrapper<[ServiceEndpoint]> {
        let request = MapRemoteStorageRequest(storagePath: StorageCodingPath.kiltServices) { owner }
        let requestFactory = StorageRequestFactory(
            remoteFactory: StorageKeyFactory(),
            operationManager: OperationManager(operationQueue: operationQueue)
        )
        let codingFactoryOperation = runtimeService.fetchCoderFactoryOperation()
        let wrapper: CompoundOperationWrapper<[ServiceKey: ServiceEndpoint]> =
            requestFactory.queryByPrefix(
                engine: connection,
                request: request,
                storagePath: StorageCodingPath.kiltServices,
                factory: { try codingFactoryOperation.extractNoCancellableResultData() }
            )
        wrapper.addDependency(operations: [codingFactoryOperation])

        let mappingOperation = ClosureOperation<[ServiceEndpoint]> {
            let result = try wrapper.targetOperation.extractNoCancellableResultData().values
            return Array(result)
        }

        let dependencies = [codingFactoryOperation] + wrapper.allOperations

        dependencies.forEach { mappingOperation.addDependency($0) }

        return CompoundOperationWrapper(targetOperation: mappingOperation, dependencies: dependencies)
    }
}

extension StorageCodingPath {
    static var kiltName: StorageCodingPath {
        StorageCodingPath(moduleName: "Web3Names", itemName: "Owner")
    }

    static var kiltServices: StorageCodingPath {
        StorageCodingPath(moduleName: "Did", itemName: "ServiceEndpoints")
    }
}

struct Web3NamesOwnership: Codable {
    let owner: AccountId
    @StringCodable var claimedAt: BigUInt
    let deposit: Deposit

    struct Deposit: Codable {
        let owner: AccountId
        @StringCodable var amount: BigUInt
    }
}

struct ServiceKey: JSONListConvertible, Hashable {
    let didIdentifier: AccountId
    let serviceId: String

    init(jsonList: [JSON], context: [CodingUserInfoKey: Any]?) throws {
        let expectedFieldsCount = 2
        let actualFieldsCount = jsonList.count
        guard expectedFieldsCount == actualFieldsCount else {
            throw JSONListConvertibleError.unexpectedNumberOfItems(
                expected: expectedFieldsCount,
                actual: actualFieldsCount
            )
        }

        didIdentifier = try jsonList[0].map(to: BytesCodable.self, with: context).wrappedValue
        let data = try jsonList[1].map(to: BytesCodable.self, with: context).wrappedValue
        serviceId = String(data: data, encoding: .utf8) ?? ""
    }
}

struct ServiceEndpoint: Decodable {
    var id: String
    var serviceTypes: [String]
    var urls: [String]

    enum CodingKeys: String, CodingKey {
        case id
        case serviceTypes
        case urls
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let id = try container.decode(BytesCodable.self, forKey: .id).wrappedValue
        self.id = String(data: id, encoding: .utf8) ?? ""
        serviceTypes = try container.decode([StringContainerType].self, forKey: .serviceTypes).map(\.value)
        urls = try container.decode([StringContainerType].self, forKey: .urls).map(\.value)
    }
}

struct StringContainerType: Decodable {
    var value: String

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let data = try container.decode(BytesCodable.self).wrappedValue
        value = String(data: data, encoding: .utf8) ?? ""
    }
}
