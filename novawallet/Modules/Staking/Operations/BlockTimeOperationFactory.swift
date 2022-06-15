import Foundation
import RobinHood

protocol BlockTimeOperationFactoryProtocol {
    func createBlockTimeOperation(
        from runtimeService: RuntimeCodingServiceProtocol,
        blockTimeEstimationService: BlockTimeEstimationServiceProtocol
    ) -> CompoundOperationWrapper<BlockTime>
}

final class BlockTimeOperationFactory {
    static let callibrationSeqSize: BlockTime = 10
    static let fallbackBlockRelaychainTime: BlockTime = 6000
    static let fallbackBlockParachainTime: BlockTime = 2 * 6000
    static let fallbackThreshold: BlockTime = 500

    let chain: ChainModel

    init(chain: ChainModel) {
        self.chain = chain
    }

    private var fallbackBlockTime: BlockTime {
        chain.isRelaychain ? Self.fallbackBlockRelaychainTime : Self.fallbackBlockParachainTime
    }

    private func createExpectedBlockTimeWrapper(
        dependingOn codingFactoryOperation: BaseOperation<RuntimeCoderFactoryProtocol>,
        fallbackTime: BlockTime,
        fallbackThreshold: BlockTime
    ) -> CompoundOperationWrapper<BlockTime> {
        let babeTimeOperation: BaseOperation<BlockTime> = PrimitiveConstantOperation.operation(
            for: .babeBlockTime,
            dependingOn: codingFactoryOperation
        )

        let minBlockTimeOperation: BaseOperation<BlockTime> = PrimitiveConstantOperation.operation(
            for: .minimumPeriodBetweenBlocks,
            dependingOn: codingFactoryOperation
        )

        let mapOperation = ClosureOperation<BlockTime> {
            let optBabeTime = try? babeTimeOperation.extractNoCancellableResultData()
            let optMinBlockTime = try? minBlockTimeOperation.extractNoCancellableResultData()

            let exptectedBlockTime = (optBabeTime ?? optMinBlockTime) ?? fallbackTime

            return exptectedBlockTime >= fallbackThreshold ? exptectedBlockTime : fallbackTime
        }

        mapOperation.addDependency(babeTimeOperation)
        mapOperation.addDependency(minBlockTimeOperation)

        return CompoundOperationWrapper(
            targetOperation: mapOperation,
            dependencies: [babeTimeOperation, minBlockTimeOperation]
        )
    }
}

extension BlockTimeOperationFactory: BlockTimeOperationFactoryProtocol {
    func createBlockTimeOperation(
        from runtimeService: RuntimeCodingServiceProtocol,
        blockTimeEstimationService: BlockTimeEstimationServiceProtocol
    ) -> CompoundOperationWrapper<BlockTime> {
        let codingFactoryOperation = runtimeService.fetchCoderFactoryOperation()
        let estimatedOperation = blockTimeEstimationService.createEstimatedBlockTimeOperation()
        let expectedWrapper = createExpectedBlockTimeWrapper(
            dependingOn: codingFactoryOperation,
            fallbackTime: fallbackBlockTime,
            fallbackThreshold: Self.fallbackThreshold
        )

        expectedWrapper.addDependency(operations: [codingFactoryOperation])

        let mapOperation = ClosureOperation<BlockTime> {
            let estimatedBlockTimeValue = try estimatedOperation.extractNoCancellableResultData()
            let expectedBlockTime = try expectedWrapper.targetOperation.extractNoCancellableResultData()
                .timeInterval

            let boundedSeqSize = min(BlockTime(estimatedBlockTimeValue.seqSize), Self.callibrationSeqSize)
            let estimatedPart = TimeInterval(boundedSeqSize) * estimatedBlockTimeValue.blockTime.timeInterval
            let constantsPart = TimeInterval(Self.callibrationSeqSize - boundedSeqSize) * expectedBlockTime

            let resultTimeInterval = (estimatedPart + constantsPart) / TimeInterval(Self.callibrationSeqSize)

            return BlockTime(resultTimeInterval.milliseconds)
        }

        mapOperation.addDependency(expectedWrapper.targetOperation)
        mapOperation.addDependency(estimatedOperation)

        let dependencies = [codingFactoryOperation, estimatedOperation] + expectedWrapper.allOperations

        return CompoundOperationWrapper(targetOperation: mapOperation, dependencies: dependencies)
    }
}
