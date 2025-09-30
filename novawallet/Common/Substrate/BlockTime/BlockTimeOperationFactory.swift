import Foundation
import Operation_iOS

protocol BlockTimeOperationFactoryProtocol {
    func createBlockTimeOperation(
        from runtimeService: RuntimeCodingServiceProtocol,
        blockTimeEstimationService: BlockTimeEstimationServiceProtocol
    ) -> CompoundOperationWrapper<BlockTime>

    func createExpectedBlockTimeWrapper(
        from runtimeService: RuntimeCodingServiceProtocol
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
        chainDefaultTime: BlockTime?,
        fallbackTime: BlockTime,
        fallbackThreshold: BlockTime
    ) -> CompoundOperationWrapper<BlockTime> {
        if let chainDefaultTime = chainDefaultTime {
            return CompoundOperationWrapper.createWithResult(chainDefaultTime)
        }

        let babeTimeOperation: BaseOperation<BlockTime> = PrimitiveConstantOperation.operation(
            for: BabePallet.blockTimePath,
            dependingOn: codingFactoryOperation
        )

        let mapOperation = ClosureOperation<BlockTime> {
            let optBabeTime = try? babeTimeOperation.extractNoCancellableResultData()

            let exptectedBlockTime = optBabeTime ?? fallbackTime

            return exptectedBlockTime >= fallbackThreshold ? exptectedBlockTime : fallbackTime
        }

        mapOperation.addDependency(babeTimeOperation)

        return CompoundOperationWrapper(
            targetOperation: mapOperation,
            dependencies: [babeTimeOperation]
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
            chainDefaultTime: chain.defaultBlockTimeMillis,
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

    func createExpectedBlockTimeWrapper(
        from runtimeService: RuntimeCodingServiceProtocol
    ) -> CompoundOperationWrapper<BlockTime> {
        let codingFactoryOperation = runtimeService.fetchCoderFactoryOperation()
        let expectedWrapper = createExpectedBlockTimeWrapper(
            dependingOn: codingFactoryOperation,
            chainDefaultTime: chain.defaultBlockTimeMillis,
            fallbackTime: fallbackBlockTime,
            fallbackThreshold: Self.fallbackThreshold
        )

        expectedWrapper.addDependency(operations: [codingFactoryOperation])

        return expectedWrapper.insertingHead(operations: [codingFactoryOperation])
    }
}
