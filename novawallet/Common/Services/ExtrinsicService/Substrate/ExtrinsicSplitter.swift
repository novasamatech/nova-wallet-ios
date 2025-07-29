import Foundation
import SubstrateSdk
import Operation_iOS

struct ExtrinsicSplittingResult {
    let closure: ExtrinsicBuilderIndexedClosure
    let numberOfExtrinsics: Int
}

protocol ExtrinsicSplitting: AnyObject {
    func adding<T: RuntimeCallable>(call: T) -> Self

    func buildWrapper(
        using operationFactory: ExtrinsicOperationFactoryProtocol
    ) -> CompoundOperationWrapper<ExtrinsicSplittingResult>
}

enum ExtrinsicSplitterError: Error {
    case extrinsicTooLarge(blockLimit: Substrate.Weight, callWeight: Substrate.Weight)
    case weightNotFound(path: CallCodingPath)
    case invalidExtrinsicIndex(index: Int, totalExtrinsics: Int)
    case noCalls
}

final class ExtrinsicSplitter {
    static let extrinsicSizePercent: BigRational = .percent(of: 80)

    let chain: ChainModel
    let chainRegistry: ChainRegistryProtocol
    let maxCallsPerExtrinsic: Int?

    private let blockLimitOperationFactory: BlockLimitOperationFactoryProtocol

    private let callWeightEstimator = CallWeightEstimatingFactory()

    private var internalCalls: [RuntimeCallCollecting] = []

    init(
        chain: ChainModel,
        maxCallsPerExtrinsic: Int?,
        chainRegistry: ChainRegistryProtocol,
        operationQueue: OperationQueue
    ) {
        self.chain = chain
        self.maxCallsPerExtrinsic = maxCallsPerExtrinsic
        self.chainRegistry = chainRegistry

        blockLimitOperationFactory = BlockLimitOperationFactory(
            chainRegistry: chainRegistry,
            operationQueue: operationQueue
        )
    }

    private func createBlockLimitWrapper() -> CompoundOperationWrapper<Substrate.Weight> {
        let blockWeightsWrapper = blockLimitOperationFactory.fetchBlockWeights(for: chain.chainId)
        let lastWeightWrapper = blockLimitOperationFactory.fetchLastBlockWeight(for: chain.chainId)

        let mappingOperation = ClosureOperation<Substrate.Weight> {
            let blockWeights = try blockWeightsWrapper.targetOperation.extractNoCancellableResultData()
            let lastBlockWeight = try lastWeightWrapper.targetOperation.extractNoCancellableResultData()

            // dont't exceed extrinsic limit
            let extrinsicLimit = blockWeights.perClass.normal.maxExtrinsic ?? .maxWeight

            // don't exceed all normal extrinsic limit in the block
            let normalClassLimit = blockWeights.perClass.normal.maxTotal.map {
                $0 - lastBlockWeight.normal
            } ?? .maxWeight

            // don't exceed total block limit
            let blockLimit = blockWeights.maxBlock - lastBlockWeight.totalWeight

            let unionLimit = extrinsicLimit
                .minByComponent(with: normalClassLimit)
                .minByComponent(with: blockLimit)

            return unionLimit * Self.extrinsicSizePercent
        }

        mappingOperation.addDependency(blockWeightsWrapper.targetOperation)
        mappingOperation.addDependency(lastWeightWrapper.targetOperation)

        return lastWeightWrapper
            .insertingHead(operations: blockWeightsWrapper.allOperations)
            .insertingTail(operation: mappingOperation)
    }

    private func extrinsicsSplitOperation(
        dependingOn blockLimitOperation: BaseOperation<Substrate.Weight>,
        callTypeWeightOperation: BaseOperation<[CallCodingPath: Substrate.Weight]>,
        internalCalls: [RuntimeCallCollecting],
        maxCallsPerExtrinsic: Int?
    ) -> ClosureOperation<ExtrinsicSplittingResult> {
        ClosureOperation<ExtrinsicSplittingResult> {
            let callTypeWeight = try callTypeWeightOperation.extractNoCancellableResultData()
            let blockLimit = try blockLimitOperation.extractNoCancellableResultData()

            var extrinsics: [[RuntimeCallCollecting]] = []
            var targetCalls: [RuntimeCallCollecting] = []
            var totalWeight: Substrate.Weight = .zero

            try internalCalls.forEach { internalCall in
                guard let callWeight = callTypeWeight[internalCall.callPath] else {
                    throw ExtrinsicSplitterError.weightNotFound(path: internalCall.callPath)
                }

                guard callWeight.fits(in: blockLimit) else {
                    throw ExtrinsicSplitterError.extrinsicTooLarge(blockLimit: blockLimit, callWeight: callWeight)
                }

                let maxCallsExceeded = if let maxCallsPerExtrinsic {
                    targetCalls.count >= maxCallsPerExtrinsic
                } else {
                    false
                }

                if (totalWeight + callWeight).fits(in: blockLimit), !maxCallsExceeded {
                    targetCalls.append(internalCall)
                    totalWeight += callWeight
                } else {
                    totalWeight = callWeight

                    extrinsics.append(targetCalls)
                    targetCalls = [internalCall]
                }
            }

            if !targetCalls.isEmpty {
                extrinsics.append(targetCalls)
            }

            let closure: ExtrinsicBuilderIndexedClosure = { builder, index in
                guard index < extrinsics.count else {
                    throw ExtrinsicSplitterError.invalidExtrinsicIndex(
                        index: index,
                        totalExtrinsics: extrinsics.count
                    )
                }

                let internalCalls = extrinsics[index]

                var innerBuilder = builder
                for internalCall in internalCalls {
                    innerBuilder = try internalCall.addingToExtrinsic(builder: innerBuilder)
                }

                return innerBuilder
            }

            return .init(closure: closure, numberOfExtrinsics: extrinsics.count)
        }
    }

    private func createFastPathWrapper(
        for internalCall: RuntimeCallCollecting
    ) -> CompoundOperationWrapper<ExtrinsicSplittingResult> {
        let mappingOperation = ClosureOperation<ExtrinsicSplittingResult> {
            let closure: ExtrinsicBuilderIndexedClosure = { builder, index in
                guard index == 0 else {
                    throw ExtrinsicSplitterError.invalidExtrinsicIndex(index: index, totalExtrinsics: 1)
                }

                return try internalCall.addingToExtrinsic(builder: builder)
            }

            return .init(closure: closure, numberOfExtrinsics: 1)
        }

        return .init(targetOperation: mappingOperation)
    }
}

extension ExtrinsicSplitter: ExtrinsicSplitting {
    func adding<T>(call: T) -> Self where T: RuntimeCallable {
        let internalCall = RuntimeCallCollector(
            call: RuntimeCall(
                moduleName: call.moduleName,
                callName: call.callName,
                args: call.args
            )
        )

        internalCalls.append(internalCall)

        return self
    }

    func buildWrapper(
        using operationFactory: ExtrinsicOperationFactoryProtocol
    ) -> CompoundOperationWrapper<ExtrinsicSplittingResult> {
        guard let firstInnerCall = internalCalls.first else {
            return CompoundOperationWrapper.createWithError(ExtrinsicSplitterError.noCalls)
        }

        guard internalCalls.count > 1 else {
            return createFastPathWrapper(for: firstInnerCall)
        }

        let blockLimitWrapper = createBlockLimitWrapper()

        let callTypeWeightWrapper = callWeightEstimator.estimateWeight(
            for: internalCalls,
            operationFactory: operationFactory
        )

        let extrinsicsSplitOperation = extrinsicsSplitOperation(
            dependingOn: blockLimitWrapper.targetOperation,
            callTypeWeightOperation: callTypeWeightWrapper.targetOperation,
            internalCalls: internalCalls,
            maxCallsPerExtrinsic: maxCallsPerExtrinsic
        )

        extrinsicsSplitOperation.addDependency(blockLimitWrapper.targetOperation)
        extrinsicsSplitOperation.addDependency(callTypeWeightWrapper.targetOperation)

        let dependencies = blockLimitWrapper.allOperations + callTypeWeightWrapper.allOperations

        return CompoundOperationWrapper(targetOperation: extrinsicsSplitOperation, dependencies: dependencies)
    }
}
