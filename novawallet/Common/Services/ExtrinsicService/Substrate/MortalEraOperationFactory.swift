import Foundation
import Operation_iOS
import SubstrateSdk
import BigInt

final class MortalEraOperationFactory {
    struct FinalizationModel {
        let blockNumber: UInt64
        let finalityLag: UInt64
    }

    static let fallbackMaxHashCount: BlockNumber = 250
    static let mortalPeriod: UInt64 = 5 * 60 * 1000

    private let blockTimeOperationFactory: BlockTimeOperationFactory

    init(chain: ChainModel) {
        blockTimeOperationFactory = BlockTimeOperationFactory(chain: chain)
    }

    private func createFinalizedHeaderOperation(
        from connection: JSONRPCEngine
    ) -> CompoundOperationWrapper<Block.Header> {
        let finalizedBlockHashOperation: JSONRPCListOperation<String> = JSONRPCListOperation(
            engine: connection,
            method: RPCMethod.getFinalizedBlockHash
        )

        let finalizedHeaderOperation: JSONRPCListOperation<Block.Header> = JSONRPCListOperation(
            engine: connection,
            method: RPCMethod.getBlockHeader
        )

        finalizedHeaderOperation.configurationBlock = {
            do {
                let blockHash = try finalizedBlockHashOperation.extractNoCancellableResultData()
                finalizedHeaderOperation.parameters = [blockHash]
            } catch {
                finalizedHeaderOperation.result = .failure(error)
            }
        }

        finalizedHeaderOperation.addDependency(finalizedBlockHashOperation)

        return CompoundOperationWrapper(
            targetOperation: finalizedHeaderOperation,
            dependencies: [finalizedBlockHashOperation]
        )
    }

    private func createBestHeaderOperation(
        from connection: JSONRPCEngine
    ) -> CompoundOperationWrapper<Block.Header> {
        let currentHeaderOperation: JSONRPCListOperation<Block.Header> = JSONRPCListOperation(
            engine: connection,
            method: RPCMethod.getBlockHeader
        )

        let bestHeaderOperation: JSONRPCListOperation<Block.Header> = JSONRPCListOperation(
            engine: connection,
            method: RPCMethod.getBlockHeader
        )

        bestHeaderOperation.configurationBlock = {
            do {
                let header = try currentHeaderOperation.extractNoCancellableResultData()

                if !header.parentHash.isEmpty {
                    bestHeaderOperation.parameters = [header.parentHash]
                } else {
                    bestHeaderOperation.result = .success(header)
                }
            } catch {
                bestHeaderOperation.result = .failure(error)
            }
        }

        bestHeaderOperation.addDependency(currentHeaderOperation)

        return CompoundOperationWrapper(
            targetOperation: bestHeaderOperation,
            dependencies: [currentHeaderOperation]
        )
    }

    private func createFinalizationModelWrapper(
        from connection: JSONRPCEngine
    ) -> CompoundOperationWrapper<FinalizationModel> {
        let finalizedHeaderWrapper = createFinalizedHeaderOperation(from: connection)
        let bestHeaderWrapper = createBestHeaderOperation(from: connection)

        let mapOperation = ClosureOperation<FinalizationModel> {
            let finalizedHeader = try finalizedHeaderWrapper.targetOperation
                .extractNoCancellableResultData()
            let bestHeader = try bestHeaderWrapper.targetOperation.extractNoCancellableResultData()

            guard
                let bestNumber = BigUInt.fromHexString(bestHeader.number),
                let finalizedNumber = BigUInt.fromHexString(finalizedHeader.number) else {
                throw BaseOperationError.unexpectedDependentResult
            }

            let finalityLag = bestNumber > finalizedNumber ? bestNumber - finalizedNumber : 0

            return FinalizationModel(blockNumber: UInt64(finalizedNumber), finalityLag: UInt64(finalityLag))
        }

        mapOperation.addDependency(finalizedHeaderWrapper.targetOperation)
        mapOperation.addDependency(bestHeaderWrapper.targetOperation)

        return CompoundOperationWrapper(
            targetOperation: mapOperation,
            dependencies: finalizedHeaderWrapper.allOperations + bestHeaderWrapper.allOperations
        )
    }

    private func createBlockTimeWrapper(
        for runtimeService: RuntimeCodingServiceProtocol
    ) -> CompoundOperationWrapper<BlockTime> {
        blockTimeOperationFactory.createExpectedBlockTimeWrapper(from: runtimeService)
    }

    private func createBlockHashCountOperation(
        dependingOn codingFactoryOperation: BaseOperation<RuntimeCoderFactoryProtocol>
    ) -> CompoundOperationWrapper<BlockNumber> {
        let blockHashCountOperation = PrimitiveConstantOperation<BlockNumber>(path: SystemPallet.blockHashCount)
        blockHashCountOperation.configurationBlock = {
            do {
                blockHashCountOperation.codingFactory = try codingFactoryOperation
                    .extractNoCancellableResultData()
            } catch {
                blockHashCountOperation.result = .failure(error)
            }
        }

        let mapOperation = ClosureOperation<BlockNumber> {
            let blockHashCount = try? blockHashCountOperation.extractNoCancellableResultData()

            return blockHashCount ?? BlockNumber(Self.fallbackMaxHashCount)
        }

        mapOperation.addDependency(blockHashCountOperation)

        return CompoundOperationWrapper(
            targetOperation: mapOperation,
            dependencies: [blockHashCountOperation]
        )
    }

    private func createMortalLengthOperation(
        runtimeService: RuntimeCodingServiceProtocol,
        dependingOn finalizationModelOperation: BaseOperation<FinalizationModel>
    ) -> CompoundOperationWrapper<UInt64> {
        let codingFactoryOperation = runtimeService.fetchCoderFactoryOperation()

        let blockHashCountWrapper = createBlockHashCountOperation(
            dependingOn: codingFactoryOperation
        )

        let blockTimeWrapper = createBlockTimeWrapper(for: runtimeService)

        blockHashCountWrapper.addDependency(operations: [codingFactoryOperation])
        blockTimeWrapper.addDependency(operations: [codingFactoryOperation])

        let mapper = ClosureOperation<UInt64> {
            let blockTime = try blockTimeWrapper.targetOperation.extractNoCancellableResultData()
            let blockHashCount = try blockHashCountWrapper.targetOperation
                .extractNoCancellableResultData()
            let finalizationModel = try finalizationModelOperation.extractNoCancellableResultData()

            guard blockTime > 0 else {
                throw BaseOperationError.unexpectedDependentResult
            }

            let unmappedPeriod = (Self.mortalPeriod / blockTime) + finalizationModel.finalityLag

            return min(UInt64(blockHashCount), unmappedPeriod)
        }

        mapper.addDependency(blockHashCountWrapper.targetOperation)
        mapper.addDependency(blockTimeWrapper.targetOperation)

        let dependencies = [codingFactoryOperation] + blockHashCountWrapper.allOperations +
            blockTimeWrapper.allOperations

        return CompoundOperationWrapper(
            targetOperation: mapper,
            dependencies: dependencies
        )
    }
}

extension MortalEraOperationFactory: ExtrinsicEraOperationFactoryProtocol {
    func createOperation(
        from connection: JSONRPCEngine,
        runtimeService: RuntimeCodingServiceProtocol
    ) -> CompoundOperationWrapper<ExtrinsicEraParameters> {
        let finalizationModelWrapper = createFinalizationModelWrapper(from: connection)

        let mortalLengthWrapper = createMortalLengthOperation(
            runtimeService: runtimeService,
            dependingOn: finalizationModelWrapper.targetOperation
        )

        mortalLengthWrapper.addDependency(wrapper: finalizationModelWrapper)

        let mapOperation = ClosureOperation<ExtrinsicEraParameters> {
            let mortalLength = try mortalLengthWrapper.targetOperation.extractNoCancellableResultData()
            let blockNumber = try finalizationModelWrapper.targetOperation.extractNoCancellableResultData().blockNumber

            let constrainedPeriod: UInt64 = min(1 << 16, max(4, mortalLength))
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

        mapOperation.addDependency(mortalLengthWrapper.targetOperation)

        return mortalLengthWrapper
            .insertingHead(operations: finalizationModelWrapper.allOperations)
            .insertingTail(operation: mapOperation)
    }
}
