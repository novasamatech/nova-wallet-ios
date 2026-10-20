import Foundation
import Operation_iOS
import SubstrateSdk

protocol MevShieldOperationFactoryProtocol {
    func createNextKeyWrapper() -> CompoundOperationWrapper<Data?>
}

enum MevShieldOperationFactoryError: Error {
    case unexpectedKeyLength(Int)
}

final class MevShieldOperationFactory {
    let runtimeProvider: RuntimeCodingServiceProtocol
    let connection: JSONRPCEngine
    let operationQueue: OperationQueue

    private let requestFactory: StorageRequestFactoryProtocol

    init(
        runtimeProvider: RuntimeCodingServiceProtocol,
        connection: JSONRPCEngine,
        operationQueue: OperationQueue
    ) {
        self.runtimeProvider = runtimeProvider
        self.connection = connection
        self.operationQueue = operationQueue

        requestFactory = StorageRequestFactory.createDefault(with: operationQueue)
    }
}

private extension MevShieldOperationFactory {
    static func supportsShielding(_ codingFactory: RuntimeCoderFactoryProtocol) -> Bool {
        codingFactory.hasCall(for: MevShieldPallet.submitEncryptedPath) &&
            codingFactory.hasStorage(for: MevShieldPallet.nextKeyPath)
    }

    func createKeyQueryWrapper(using codingFactory: RuntimeCoderFactoryProtocol) -> CompoundOperationWrapper<Data?> {
        let queryWrapper: CompoundOperationWrapper<StorageResponse<BytesCodable>> = requestFactory.queryItem(
            engine: connection,
            factory: { codingFactory },
            storagePath: MevShieldPallet.nextKeyPath,
            at: nil
        )

        let mapOperation = ClosureOperation<Data?> {
            let response = try queryWrapper.targetOperation.extractNoCancellableResultData()

            guard let key = response.value?.wrappedValue else {
                return nil
            }

            guard key.count == MevShieldPallet.encapsulationKeyLength else {
                throw MevShieldOperationFactoryError.unexpectedKeyLength(key.count)
            }

            return key
        }

        mapOperation.addDependency(queryWrapper.targetOperation)

        return queryWrapper.insertingTail(operation: mapOperation)
    }
}

extension MevShieldOperationFactory: MevShieldOperationFactoryProtocol {
    func createNextKeyWrapper() -> CompoundOperationWrapper<Data?> {
        let codingFactoryOperation = runtimeProvider.fetchCoderFactoryOperation()

        let keyWrapper = OperationCombiningService<Data>.compoundOptionalWrapper(
            operationManager: OperationManager(operationQueue: operationQueue)
        ) {
            let codingFactory = try codingFactoryOperation.extractNoCancellableResultData()

            guard Self.supportsShielding(codingFactory) else {
                return nil
            }

            return self.createKeyQueryWrapper(using: codingFactory)
        }

        keyWrapper.addDependency(operations: [codingFactoryOperation])

        return keyWrapper.insertingHead(operations: [codingFactoryOperation])
    }
}
