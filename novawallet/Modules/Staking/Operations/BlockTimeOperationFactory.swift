import Foundation
import RobinHood

protocol BlockTimeOperationFactoryProtocol {
    func createBlockTimeOperation(
        from runtimeService: RuntimeCodingServiceProtocol,
        blockTimeEstimationService: BlockTimeEstimationServiceProtocol
    ) -> CompoundOperationWrapper<Moment>
}

final class BlockTimeOperationFactory {
    static let callibrationSeqSize: Moment = 10
    static let fallbackBlockRelaychainTime: Moment = 6000
    static let fallbackBlockParachainTime: Moment = 2 * 6000
    static let fallbackThreshold: Moment = 500

    let chain: ChainModel

    init(chain: ChainModel) {
        self.chain = chain
    }

    private var fallbackBlockTime: Moment {
        chain.isRelaychain ? Self.fallbackBlockRelaychainTime : Self.fallbackBlockParachainTime
    }

    private func createExpectedBlockTimeWrapper(
        dependingOn codingFactoryOperation: BaseOperation<RuntimeCoderFactoryProtocol>,
        fallbackTime: Moment,
        fallbackThreshold: Moment
    ) -> CompoundOperationWrapper<Moment> {
        let babeTimeOperation: BaseOperation<Moment> = PrimitiveConstantOperation.operation(
            for: .babeBlockTime,
            dependingOn: codingFactoryOperation
        )

        let minBlockTimeOperation: BaseOperation<Moment> = PrimitiveConstantOperation.operation(
            for: .minimumPeriodBetweenBlocks,
            dependingOn: codingFactoryOperation
        )

        let mapOperation = ClosureOperation<Moment> {
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
    ) -> CompoundOperationWrapper<Moment> {
        let codingFactoryOperation = runtimeService.fetchCoderFactoryOperation()
        let estimatedOperation = blockTimeEstimationService.createEstimatedBlockTimeOperation()
        let expectedWrapper = createExpectedBlockTimeWrapper(
            dependingOn: codingFactoryOperation,
            fallbackTime: fallbackBlockTime,
            fallbackThreshold: Self.fallbackThreshold
        )

        expectedWrapper.addDependency(operations: [codingFactoryOperation])

        let mapOperation = ClosureOperation<Moment> {
            let estimatedBlockTimeValue = try estimatedOperation.extractNoCancellableResultData()
            let expectedBlockTime = try expectedWrapper.targetOperation.extractNoCancellableResultData()

            let boundedSeqSize = min(Moment(estimatedBlockTimeValue.seqSize), Self.callibrationSeqSize)
            let estimatedPart = boundedSeqSize * estimatedBlockTimeValue.blockTime
            let constantsPart = (Self.callibrationSeqSize - boundedSeqSize) * expectedBlockTime

            return (estimatedPart + constantsPart) / Self.callibrationSeqSize
        }

        mapOperation.addDependency(expectedWrapper.targetOperation)
        mapOperation.addDependency(estimatedOperation)

        let dependencies = [codingFactoryOperation, estimatedOperation] + expectedWrapper.allOperations

        return CompoundOperationWrapper(targetOperation: mapOperation, dependencies: dependencies)
    }
}
