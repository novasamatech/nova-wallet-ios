import Foundation
import Operation_iOS

extension PrimitiveConstantOperation {
    static func operation(
        for path: ConstantCodingPath,
        dependingOn factoryOperation: BaseOperation<RuntimeCoderFactoryProtocol>,
        fallbackValue: T? = nil
    ) -> BaseOperation<T> {
        operation(
            oneOfPaths: [path],
            dependingOn: factoryOperation,
            fallbackValue: fallbackValue
        )
    }

    static func operation(
        oneOfPaths: [ConstantCodingPath],
        dependingOn factoryOperation: BaseOperation<RuntimeCoderFactoryProtocol>,
        fallbackValue: T? = nil
    ) -> BaseOperation<T> {
        let operation = PrimitiveConstantOperation<T>(
            oneOfPaths: oneOfPaths,
            fallbackValue: fallbackValue
        )

        operation.configurationBlock = {
            do {
                operation.codingFactory = try factoryOperation.extractNoCancellableResultData()
            } catch {
                operation.result = .failure(error)
            }
        }

        return operation
    }

    static func wrapper(
        for path: ConstantCodingPath,
        runtimeService: RuntimeCodingServiceProtocol,
        fallbackValue: T? = nil
    ) -> CompoundOperationWrapper<T> {
        let factoryOperation = runtimeService.fetchCoderFactoryOperation()

        let operation = PrimitiveConstantOperation<T>(path: path, fallbackValue: fallbackValue)

        operation.configurationBlock = {
            do {
                operation.codingFactory = try factoryOperation.extractNoCancellableResultData()
            } catch {
                operation.result = .failure(error)
            }
        }

        operation.addDependency(factoryOperation)

        return CompoundOperationWrapper(targetOperation: operation, dependencies: [factoryOperation])
    }

    static func wrapperNilIfMissing(
        for path: ConstantCodingPath,
        runtimeService: RuntimeCodingServiceProtocol
    ) -> CompoundOperationWrapper<T?> {
        let fetchWrapper = wrapper(for: path, runtimeService: runtimeService)

        let mappingOperation = ClosureOperation<T?> {
            do {
                return try fetchWrapper.targetOperation.extractNoCancellableResultData()
            } catch {
                if let storageError = error as? StorageDecodingOperationError, storageError == .invalidStoragePath {
                    return nil
                } else {
                    throw error
                }
            }
        }

        mappingOperation.addDependency(fetchWrapper.targetOperation)

        return CompoundOperationWrapper(targetOperation: mappingOperation, dependencies: fetchWrapper.allOperations)
    }
}

extension StorageConstantOperation {
    static func operation(
        path: ConstantCodingPath,
        dependingOn factoryOperation: BaseOperation<RuntimeCoderFactoryProtocol>,
        fallbackValue: T? = nil
    ) -> BaseOperation<T> {
        let operation = StorageConstantOperation(path: path, fallbackValue: fallbackValue)

        operation.configurationBlock = {
            do {
                operation.codingFactory = try factoryOperation.extractNoCancellableResultData()
            } catch {
                operation.result = .failure(error)
            }
        }

        return operation
    }
}
