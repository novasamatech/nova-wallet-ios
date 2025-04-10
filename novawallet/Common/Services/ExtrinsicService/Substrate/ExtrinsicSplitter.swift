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

    typealias CallConverter = (RuntimeJsonContext?) throws -> JSON

    struct InternalCall {
        let path: CallCodingPath
        let args: CallConverter

        func toRuntimeCall(using context: RuntimeJsonContext?) throws -> RuntimeCall<JSON> {
            let argsModel = try args(context)

            return .init(moduleName: path.moduleName, callName: path.callName, args: argsModel)
        }
    }

    let chain: ChainModel
    let chainRegistry: ChainRegistryProtocol
    let maxCallsPerExtrinsic: Int?

    private let blockLimitOperationFactory: BlockLimitOperationFactoryProtocol

    private var internalCalls: [InternalCall] = []

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

    func estimateWeightForCallTypesWrapper(
        using operationFactory: ExtrinsicOperationFactoryProtocol,
        dependingOn codingFactoryOperation: BaseOperation<RuntimeCoderFactoryProtocol>
    ) -> CompoundOperationWrapper<[CallCodingPath: Substrate.Weight]> {
        let callTypes = internalCalls.reduce(into: [CallCodingPath: InternalCall]()) { accum, call in
            if accum[call.path] == nil {
                accum[call.path] = call
            }
        }

        let targetCalls = Array(callTypes.values)

        guard !targetCalls.isEmpty else {
            return CompoundOperationWrapper.createWithResult([:])
        }

        let closure: ExtrinsicBuilderIndexedClosure = { builder, index in
            let runtimeContext = try codingFactoryOperation.extractNoCancellableResultData().createRuntimeJsonContext()
            let runtimeCall = try targetCalls[index].toRuntimeCall(using: runtimeContext)

            return try builder.adding(call: runtimeCall)
        }

        let feeWrapper = operationFactory.estimateFeeOperation(closure, numberOfExtrinsics: callTypes.count)

        let mapOperation = ClosureOperation<[CallCodingPath: Substrate.Weight]> {
            let feeResults = try feeWrapper.targetOperation.extractNoCancellableResultData().results

            return try zip(targetCalls, feeResults).reduce(into: [CallCodingPath: Substrate.Weight]()) { accum, pair in
                let callPath = pair.0.path
                let feeResult = pair.1.result

                let fee = try feeResult.get()
                accum[callPath] = fee.weight
            }
        }

        mapOperation.addDependency(feeWrapper.targetOperation)

        return CompoundOperationWrapper(targetOperation: mapOperation, dependencies: feeWrapper.allOperations)
    }

    private func extrinsicsSplitOperation(
        dependingOn blockLimitOperation: BaseOperation<Substrate.Weight>,
        callTypeWeightOperation: BaseOperation<[CallCodingPath: Substrate.Weight]>,
        codingFactoryOperation: BaseOperation<RuntimeCoderFactoryProtocol>,
        internalCalls: [InternalCall],
        maxCallsPerExtrinsic: Int?
    ) -> ClosureOperation<ExtrinsicSplittingResult> {
        ClosureOperation<ExtrinsicSplittingResult> {
            let callTypeWeight = try callTypeWeightOperation.extractNoCancellableResultData()
            let blockLimit = try blockLimitOperation.extractNoCancellableResultData()
            let runtimeContext = try codingFactoryOperation.extractNoCancellableResultData().createRuntimeJsonContext()

            var extrinsics: [[InternalCall]] = []
            var targetCalls: [InternalCall] = []
            var totalWeight: Substrate.Weight = .zero

            try internalCalls.forEach { internalCall in
                guard let callWeight = callTypeWeight[internalCall.path] else {
                    throw ExtrinsicSplitterError.weightNotFound(path: internalCall.path)
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
                    let runtimeCall = try internalCall.toRuntimeCall(using: runtimeContext)
                    innerBuilder = try innerBuilder.adding(call: runtimeCall)
                }

                return innerBuilder
            }

            return .init(closure: closure, numberOfExtrinsics: extrinsics.count)
        }
    }

    private func createFastPathWrapper(
        for internalCall: InternalCall,
        runtimeProvider: RuntimeProviderProtocol
    ) -> CompoundOperationWrapper<ExtrinsicSplittingResult> {
        let codingFactoryOperation = runtimeProvider.fetchCoderFactoryOperation()

        let mappingOperation = ClosureOperation<ExtrinsicSplittingResult> {
            let runtimeContext = try codingFactoryOperation.extractNoCancellableResultData().createRuntimeJsonContext()

            let closure: ExtrinsicBuilderIndexedClosure = { builder, index in
                guard index == 0 else {
                    throw ExtrinsicSplitterError.invalidExtrinsicIndex(index: index, totalExtrinsics: 1)
                }

                var innerBuilder = builder
                let runtimeCall = try internalCall.toRuntimeCall(using: runtimeContext)
                innerBuilder = try innerBuilder.adding(call: runtimeCall)

                return innerBuilder
            }

            return .init(closure: closure, numberOfExtrinsics: 1)
        }

        mappingOperation.addDependency(codingFactoryOperation)

        return .init(targetOperation: mappingOperation, dependencies: [codingFactoryOperation])
    }
}

extension ExtrinsicSplitter: ExtrinsicSplitting {
    func adding<T>(call: T) -> Self where T: RuntimeCallable {
        let internalCall = InternalCall(path: .init(moduleName: call.moduleName, callName: call.callName)) { context in
            try call.args.toScaleCompatibleJSON(with: context?.toRawContext())
        }

        internalCalls.append(internalCall)

        return self
    }

    func buildWrapper(
        using operationFactory: ExtrinsicOperationFactoryProtocol
    ) -> CompoundOperationWrapper<ExtrinsicSplittingResult> {
        guard let firstInnerCall = internalCalls.first else {
            return CompoundOperationWrapper.createWithError(ExtrinsicSplitterError.noCalls)
        }

        guard let runtimeProvider = chainRegistry.getRuntimeProvider(for: chain.chainId) else {
            return CompoundOperationWrapper.createWithError(ChainRegistryError.runtimeMetadaUnavailable)
        }

        guard internalCalls.count > 1 else {
            return createFastPathWrapper(for: firstInnerCall, runtimeProvider: runtimeProvider)
        }

        let codingFactoryOperation = runtimeProvider.fetchCoderFactoryOperation()

        let blockLimitWrapper = createBlockLimitWrapper()

        let callTypeWeightWrapper = estimateWeightForCallTypesWrapper(
            using: operationFactory,
            dependingOn: codingFactoryOperation
        )

        let extrinsicsSplitOperation = extrinsicsSplitOperation(
            dependingOn: blockLimitWrapper.targetOperation,
            callTypeWeightOperation: callTypeWeightWrapper.targetOperation,
            codingFactoryOperation: codingFactoryOperation,
            internalCalls: internalCalls,
            maxCallsPerExtrinsic: maxCallsPerExtrinsic
        )

        callTypeWeightWrapper.addDependency(operations: [codingFactoryOperation])
        extrinsicsSplitOperation.addDependency(blockLimitWrapper.targetOperation)
        extrinsicsSplitOperation.addDependency(callTypeWeightWrapper.targetOperation)

        let dependencies = [codingFactoryOperation] + blockLimitWrapper.allOperations +
            callTypeWeightWrapper.allOperations

        return CompoundOperationWrapper(targetOperation: extrinsicsSplitOperation, dependencies: dependencies)
    }
}
