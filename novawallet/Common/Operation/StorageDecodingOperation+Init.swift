import Foundation
import RobinHood

extension PrimitiveConstantOperation {
    static func operation(
        for path: ConstantCodingPath,
        dependingOn factoryOperation: BaseOperation<RuntimeCoderFactoryProtocol>,
        fallbackValue: T? = nil
    ) -> BaseOperation<T> {
        let operation = PrimitiveConstantOperation<T>(path: path, fallbackValue: fallbackValue)

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
