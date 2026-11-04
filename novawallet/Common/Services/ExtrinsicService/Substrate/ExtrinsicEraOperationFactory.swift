import Foundation
import Operation_iOS
import SubstrateSdk

struct ExtrinsicEraParameters {
    let blockNumber: BlockNumber
    let extrinsicEra: Era
}

extension ExtrinsicEraParameters {
    static func mortal(blockNumber: UInt64, period requestedPeriod: UInt64) -> ExtrinsicEraParameters {
        let constrainedPeriod: UInt64 = min(1 << 16, max(4, requestedPeriod))
        var period: UInt64 = 1

        while period < constrainedPeriod {
            period = period << 1
        }

        let unquantizedPhase = blockNumber % period
        let quantizeFactor = max(period >> 12, 1)
        let phase = (unquantizedPhase / quantizeFactor) * quantizeFactor

        let eraBlockNumber = ((blockNumber - phase) / period) * period + phase

        return ExtrinsicEraParameters(
            blockNumber: BlockNumber(eraBlockNumber),
            extrinsicEra: .mortal(period: period, phase: phase)
        )
    }
}

protocol ExtrinsicEraOperationFactoryProtocol {
    func createOperation(
        from connection: JSONRPCEngine,
        runtimeService: RuntimeCodingServiceProtocol
    ) -> CompoundOperationWrapper<ExtrinsicEraParameters>
}
