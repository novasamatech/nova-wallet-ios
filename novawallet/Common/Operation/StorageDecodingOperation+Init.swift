import Foundation
import RobinHood

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
}
