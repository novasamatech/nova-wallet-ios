import Foundation
import SubstrateSdk
import Operation_iOS

extension RuntimeCodingServiceProtocol {
    func createDecodingWrapper<T: Decodable>(for data: Data, of type: String) -> CompoundOperationWrapper<T> {
        let codingFactoryOperation = fetchCoderFactoryOperation()

        let decodingOperation = ClosureOperation<T> {
            let codingFactory = try codingFactoryOperation.extractNoCancellableResultData()

            let decoder = try codingFactory.createDecoder(from: data)

            return try decoder.read(
                of: type,
                with: codingFactory.createRuntimeJsonContext().toRawContext()
            )
        }

        decodingOperation.addDependency(codingFactoryOperation)

        return CompoundOperationWrapper(
            targetOperation: decodingOperation,
            dependencies: [codingFactoryOperation]
        )
    }
}
