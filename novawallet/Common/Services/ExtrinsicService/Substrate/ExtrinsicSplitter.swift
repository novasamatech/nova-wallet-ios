import Foundation
import SubstrateSdk
import RobinHood

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
    case extrinsicTooLarge(blockLimit: UInt64, callWeight: UInt64)
    case weightNotFound(path: CallCodingPath)
    case invalidExtrinsicIndex(index: Int, totalExtrinsics: Int)
    case noCalls
}

final class ExtrinsicSplitter {
    static let maxExtrinsicSizePercent: CGFloat = 0.8
    static let blockSizeMultiplier: CGFloat = 0.64

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

    private var internalCalls: [InternalCall] = []

    init(chain: ChainModel, chainRegistry: ChainRegistryProtocol = ChainRegistryFacade.sharedRegistry) {
        self.chain = chain
        self.chainRegistry = chainRegistry
    }

    private func createBlockLimitWrapper(
        dependingOn codingFactoryOperation: BaseOperation<RuntimeCoderFactoryProtocol>
    ) -> CompoundOperationWrapper<UInt64> {
        let blockWeightsOperation = StorageConstantOperation<BlockWeights>(
            path: .blockWeights
        )

        blockWeightsOperation.configurationBlock = {
            do {
                blockWeightsOperation.codingFactory = try codingFactoryOperation.extractNoCancellableResultData()
            } catch {
                blockWeightsOperation.result = .failure(error)
            }
        }

        let mappingOperation = ClosureOperation<UInt64> {
            let blockWeights = try blockWeightsOperation.extractNoCancellableResultData()

            if let maxExtrinsicWeight = blockWeights.normalExtrinsicMaxWeight {
                return UInt64(CGFloat(maxExtrinsicWeight) * Self.maxExtrinsicSizePercent)
            } else {
                return UInt64(CGFloat(blockWeights.maxBlock) * Self.blockSizeMultiplier)
            }
        }

        mappingOperation.addDependency(blockWeightsOperation)

        return CompoundOperationWrapper(targetOperation: mappingOperation, dependencies: [blockWeightsOperation])
    }

    func estimateWeightForCallTypesWrapper(
        using operationFactory: ExtrinsicOperationFactoryProtocol,
        dependingOn codingFactoryOperation: BaseOperation<RuntimeCoderFactoryProtocol>
    ) -> CompoundOperationWrapper<[CallCodingPath: UInt64]> {
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

        let mapOperation = ClosureOperation<[CallCodingPath: UInt64]> {
            let feeResults = try feeWrapper.targetOperation.extractNoCancellableResultData().results

            return try zip(targetCalls, feeResults).reduce(into: [CallCodingPath: UInt64]()) { accum, pair in
                let callPath = pair.0.path
                let feeResult = pair.1.result

                accum[callPath] = try feeResult.get().weight
            }
        }

        mapOperation.addDependency(feeWrapper.targetOperation)

        return CompoundOperationWrapper(targetOperation: mapOperation, dependencies: feeWrapper.allOperations)
    }

    private func extrinsicsSplitOperation(
        dependingOn blockLimitOperation: BaseOperation<UInt64>,
        callTypeWeightOperation: BaseOperation<[CallCodingPath: UInt64]>,
        codingFactoryOperation: BaseOperation<RuntimeCoderFactoryProtocol>,
        internalCalls: [InternalCall]
    ) -> ClosureOperation<ExtrinsicSplittingResult> {
        ClosureOperation<ExtrinsicSplittingResult> {
            let callTypeWeight = try callTypeWeightOperation.extractNoCancellableResultData()
            let blockLimit = try blockLimitOperation.extractNoCancellableResultData()
            let runtimeContext = try codingFactoryOperation.extractNoCancellableResultData().createRuntimeJsonContext()

            var extrinsics: [[InternalCall]] = []
            var targetCalls: [InternalCall] = []
            var totalWeight: UInt64 = 0

            try internalCalls.forEach { internalCall in
                guard let callWeight = callTypeWeight[internalCall.path] else {
                    throw ExtrinsicSplitterError.weightNotFound(path: internalCall.path)
                }

                guard blockLimit >= callWeight else {
                    throw ExtrinsicSplitterError.extrinsicTooLarge(blockLimit: blockLimit, callWeight: callWeight)
                }

                if blockLimit >= totalWeight + callWeight {
                    targetCalls.append(internalCall)
                    totalWeight += callWeight
                } else {
                    totalWeight = 0

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

        let blockLimitWrapper = createBlockLimitWrapper(dependingOn: codingFactoryOperation)

        let callTypeWeightWrapper = estimateWeightForCallTypesWrapper(
            using: operationFactory,
            dependingOn: codingFactoryOperation
        )

        let extrinsicsSplitOperation = extrinsicsSplitOperation(
            dependingOn: blockLimitWrapper.targetOperation,
            callTypeWeightOperation: callTypeWeightWrapper.targetOperation,
            codingFactoryOperation: codingFactoryOperation,
            internalCalls: internalCalls
        )

        blockLimitWrapper.addDependency(operations: [codingFactoryOperation])
        callTypeWeightWrapper.addDependency(operations: [codingFactoryOperation])
        extrinsicsSplitOperation.addDependency(blockLimitWrapper.targetOperation)
        extrinsicsSplitOperation.addDependency(callTypeWeightWrapper.targetOperation)

        let dependencies = [codingFactoryOperation] + blockLimitWrapper.allOperations +
            callTypeWeightWrapper.allOperations

        return CompoundOperationWrapper(targetOperation: extrinsicsSplitOperation, dependencies: dependencies)
    }
}
