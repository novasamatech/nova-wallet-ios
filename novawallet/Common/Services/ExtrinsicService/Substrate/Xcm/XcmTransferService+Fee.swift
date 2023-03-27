import Foundation
import RobinHood
import BigInt
import SubstrateSdk

extension XcmTransferService {
    func createStardardFeeEstimationWrapper(
        chain: ChainModel,
        message: Xcm.Message,
        maxWeight: BigUInt
    ) -> CompoundOperationWrapper<FeeWithWeight> {
        guard let runtimeProvider = chainRegistry.getRuntimeProvider(for: chain.chainId) else {
            return CompoundOperationWrapper.createWithError(ChainRegistryError.runtimeMetadaUnavailable)
        }

        do {
            let moduleWrapper = createModuleResolutionWrapper(for: .xcmpallet, runtimeProvider: runtimeProvider)

            let optChainAccount = wallet.fetch(for: chain.accountRequest())
            let operationFactory = try createExtrinsicOperationFactory(for: chain, chainAccount: optChainAccount)

            let coderFactoryOperation = runtimeProvider.fetchCoderFactoryOperation()

            let wrapper = operationFactory.estimateFeeOperation { builder in
                let moduleName = try moduleWrapper.targetOperation.extractNoCancellableResultData()
                let codingFactory = try coderFactoryOperation.extractNoCancellableResultData()
                return try Xcm.appendExecuteCall(
                    for: message,
                    maxWeight: maxWeight,
                    module: moduleName,
                    codingFactory: codingFactory,
                    builder: builder
                )
            }

            wrapper.addDependency(wrapper: moduleWrapper)
            wrapper.addDependency(operations: [coderFactoryOperation])

            let mapperOperation = ClosureOperation<FeeWithWeight> {
                let response = try wrapper.targetOperation.extractNoCancellableResultData()

                guard let fee = BigUInt(response.fee) else {
                    throw CommonError.dataCorruption
                }

                return FeeWithWeight(fee: fee, weight: BigUInt(response.weight))
            }

            mapperOperation.addDependency(wrapper.targetOperation)

            let dependencies = [coderFactoryOperation] + moduleWrapper.allOperations +
                wrapper.allOperations

            return CompoundOperationWrapper(targetOperation: mapperOperation, dependencies: dependencies)
        } catch {
            return CompoundOperationWrapper.createWithError(error)
        }
    }

    func createOneOfFeeEstimationWrapper(
        for chain: ChainModel,
        message: Xcm.Message,
        info: XcmAssetTransferFee,
        baseWeight: BigUInt
    ) -> CompoundOperationWrapper<FeeWithWeight> {
        let maxWeight = baseWeight * BigUInt(message.instructionsCount)

        switch info.mode.type {
        case .proportional:
            let coefficient: BigUInt = info.mode.value.flatMap { BigUInt($0) } ?? 0
            let fee = coefficient * maxWeight / Self.weightPerSecond
            let model = FeeWithWeight(fee: fee, weight: maxWeight)
            return CompoundOperationWrapper.createWithResult(model)
        case .standard:
            return createStardardFeeEstimationWrapper(chain: chain, message: message, maxWeight: maxWeight)
        }
    }

    func createDestinationFeeWrapper(
        for message: Xcm.Message,
        request: XcmUnweightedTransferRequest,
        xcmTransfers: XcmTransfers
    ) -> CompoundOperationWrapper<FeeWithWeight> {
        guard let feeInfo = xcmTransfers.destinationFee(
            from: request.origin.chainAssetId,
            to: request.destination.chain.chainId
        ) else {
            let error = XcmTransferFactoryError.noDestinationFee(
                origin: request.origin.chainAssetId,
                destination: request.destination.chain.chainId
            )

            return CompoundOperationWrapper.createWithError(error)
        }

        guard let baseWeight = xcmTransfers.baseWeight(for: request.destination.chain.chainId) else {
            let error = XcmTransferFactoryError.noBaseWeight(request.destination.chain.chainId)
            return CompoundOperationWrapper.createWithError(error)
        }

        return createOneOfFeeEstimationWrapper(
            for: request.destination.chain,
            message: message,
            info: feeInfo,
            baseWeight: baseWeight
        )
    }

    func createReserveFeeWrapper(
        for message: Xcm.Message,
        request: XcmUnweightedTransferRequest,
        xcmTransfers: XcmTransfers
    ) -> CompoundOperationWrapper<FeeWithWeight> {
        guard let feeInfo = xcmTransfers.reserveFee(from: request.origin.chainAssetId) else {
            let error = XcmTransferFactoryError.noReserveFee(request.origin.chainAssetId)
            return CompoundOperationWrapper.createWithError(error)
        }

        guard let baseWeight = xcmTransfers.baseWeight(for: request.reserve.chain.chainId) else {
            let error = XcmTransferFactoryError.noBaseWeight(request.reserve.chain.chainId)
            return CompoundOperationWrapper.createWithError(error)
        }

        return createOneOfFeeEstimationWrapper(
            for: request.reserve.chain,
            message: message,
            info: feeInfo,
            baseWeight: baseWeight
        )
    }
}
