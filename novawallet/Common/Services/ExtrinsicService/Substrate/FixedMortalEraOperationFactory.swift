import Foundation
import Operation_iOS
import SubstrateSdk
import BigInt

final class FixedMortalEraOperationFactory {
    let period: UInt64

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

    func createFinalizedHeaderWrapper(from connection: JSONRPCEngine) -> CompoundOperationWrapper<Block.Header> {
        let finalizedHashOperation = JSONRPCListOperation<String>(
            engine: connection,
            method: RPCMethod.getFinalizedBlockHash
        )

        let headerOperation = JSONRPCListOperation<Block.Header>(
            engine: connection,
            method: RPCMethod.getBlockHeader
        )

        headerOperation.configurationBlock = {
            do {
                headerOperation.parameters = [try finalizedHashOperation.extractNoCancellableResultData()]
            } catch {
                headerOperation.result = .failure(error)
            }
        }

        headerOperation.addDependency(finalizedHashOperation)

        return CompoundOperationWrapper(targetOperation: headerOperation, dependencies: [finalizedHashOperation])
    }
}

extension FixedMortalEraOperationFactory {
    func createParametersWrapper(from connection: JSONRPCEngine) -> CompoundOperationWrapper<ExtrinsicEraParameters> {
        let headerWrapper = createFinalizedHeaderWrapper(from: connection)

        let period = period

        let mapOperation = ClosureOperation<ExtrinsicEraParameters> {
            let header = try headerWrapper.targetOperation.extractNoCancellableResultData()

            guard
                let number = BigUInt.fromHexString(header.number),
                let blockNumber = BlockNumber(exactly: number) else {
                throw BaseOperationError.unexpectedDependentResult
            }

            return ExtrinsicEraParameters(
                blockNumber: blockNumber,
                extrinsicEra: .mortal(period: period, phase: UInt64(blockNumber) % period)
            )
        }

        mapOperation.addDependency(headerWrapper.targetOperation)

        return headerWrapper.insertingTail(operation: mapOperation)
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
