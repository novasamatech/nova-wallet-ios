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
    static let callibrationSeqSize: Int = 10
    static let fallbackBlockRelaychainTime: BlockTime = 6000
    static let fallbackBlockParachainTime: BlockTime = 2 * 6000
    static let fallbackThreshold: BlockTime = 500

    /// Sampled block time is trusted only while it stays within this factor of the block time declared in the chain
    /// config. The config is maintained remotely, whereas a sampling flaw (or a stale sample persisted before a runtime
    /// upgrade) needs an app release to fix, so the config wins when the two disagree by this much.
    static let configuredBlockTimeToleranceFactor: BlockTime = 2

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

extension BlockTimeOperationFactory {
    /// Blends on-device `estimated` block time with the `expected` one from constants/config: the more windows were
    /// sampled (up to `callibrationSeqSize`) the more weight the samples get. When the chain config declares
    /// `configured` block time, samples that are implausible against it are discarded and the configured value is used.
    static func predictBlockTime(
        estimated: EstimatedBlockTime,
        expected: BlockTime,
        configured: BlockTime?
    ) -> BlockTime {
        guard estimated.seqSize > 0 else {
            return expected
        }

        if let configured, !isPlausible(sampled: estimated.blockTime, against: configured) {
            return configured
        }

        let boundedSeqSize = BlockTime(min(estimated.seqSize, callibrationSeqSize))
        let calibrationSize = BlockTime(callibrationSeqSize)
        let estimatedPart = boundedSeqSize * estimated.blockTime
        let constantsPart = (calibrationSize - boundedSeqSize) * expected

        return (estimatedPart + constantsPart) / calibrationSize
    }

    private static func isPlausible(sampled: BlockTime, against configured: BlockTime) -> Bool {
        let lowerBound = configured / configuredBlockTimeToleranceFactor
        let upperBound = configured * configuredBlockTimeToleranceFactor

        return (lowerBound ... upperBound).contains(sampled)
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

        let configuredBlockTime = chain.defaultBlockTimeMillis

        let mapOperation = ClosureOperation<BlockTime> {
            let estimatedBlockTime = try estimatedOperation.extractNoCancellableResultData()
            let expectedBlockTime = try expectedWrapper.targetOperation.extractNoCancellableResultData()

            return Self.predictBlockTime(
                estimated: estimatedBlockTime,
                expected: expectedBlockTime,
                configured: configuredBlockTime
            )
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
