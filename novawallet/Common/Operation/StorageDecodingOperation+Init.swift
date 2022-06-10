import Foundation
import RobinHood

extension PrimitiveConstantOperation {
    static func operation(
        for path: ConstantCodingPath,
        dependingOn factoryOperation: BaseOperation<RuntimeCoderFactoryProtocol>
    ) -> BaseOperation<T> {
        let operation = PrimitiveConstantOperation<T>(path: path)

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
