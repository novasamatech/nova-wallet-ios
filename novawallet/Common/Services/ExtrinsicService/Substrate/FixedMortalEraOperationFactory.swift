import Foundation
import Operation_iOS
import SubstrateSdk

final class FixedMortalEraOperationFactory {
    let period: UInt64

    private let finalizedHeaderOperationFactory = FinalizedHeaderOperationFactory()

    init(period: UInt64) {
        self.period = Self.encodablePeriod(for: period)
    }
}

private extension FixedMortalEraOperationFactory {
    static let minPeriod: UInt64 = 4
    static let maxPeriod: UInt64 = 1 << 16

    static func encodablePeriod(for period: UInt64) -> UInt64 {
        let target = min(period, maxPeriod)
        var encodable = minPeriod

        while encodable < target {
            encodable <<= 1
        }

        return encodable
    }
}

extension FixedMortalEraOperationFactory {
    func createParametersWrapper(from connection: JSONRPCEngine) -> CompoundOperationWrapper<ExtrinsicEraParameters> {
        let numberWrapper = finalizedHeaderOperationFactory.createBlockNumberWrapper(from: connection)

        let period = period

        let mapOperation = ClosureOperation<ExtrinsicEraParameters> {
            let blockNumber = try numberWrapper.targetOperation.extractNoCancellableResultData()

            return ExtrinsicEraParameters(
                blockNumber: blockNumber,
                extrinsicEra: .mortal(period: period, phase: UInt64(blockNumber) % period)
            )
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
