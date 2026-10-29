import Foundation
import Operation_iOS
import SubstrateSdk

final class FixedMortalEraOperationFactory {
    private let period: UInt64

    private let finalizedHeaderOperationFactory = FinalizedHeaderOperationFactory()

    init(period: UInt64) {
        self.period = period
    }
}

extension FixedMortalEraOperationFactory {
    func createParametersWrapper(from connection: JSONRPCEngine) -> CompoundOperationWrapper<ExtrinsicEraParameters> {
        let numberWrapper = finalizedHeaderOperationFactory.createBlockNumberWrapper(from: connection)

        let period = period

        let mapOperation = ClosureOperation<ExtrinsicEraParameters> {
            let blockNumber = try numberWrapper.targetOperation.extractNoCancellableResultData()

            return .mortal(blockNumber: UInt64(blockNumber), period: period)
        }

        mapOperation.addDependency(numberWrapper.targetOperation)

        return numberWrapper.insertingTail(operation: mapOperation)
    }
}

extension FixedMortalEraOperationFactory: ExtrinsicEraOperationFactoryProtocol {
    func createOperation(
        from connection: JSONRPCEngine,
        runtimeService _: RuntimeCodingServiceProtocol
    ) -> CompoundOperationWrapper<ExtrinsicEraParameters> {
        createParametersWrapper(from: connection)
    }
}
