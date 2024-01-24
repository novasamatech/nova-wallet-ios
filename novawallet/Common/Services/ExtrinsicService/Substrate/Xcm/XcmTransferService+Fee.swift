import Foundation
import RobinHood
import BigInt
import SubstrateSdk

extension XcmTransferService {
    func createStardardFeeEstimationWrapper(
        chain: ChainModel,
        message: Xcm.Message,
        maxWeight: BigUInt
    ) -> CompoundOperationWrapper<ExtrinsicFeeProtocol> {
        guard let runtimeProvider = chainRegistry.getRuntimeProvider(for: chain.chainId) else {
            return CompoundOperationWrapper.createWithError(ChainRegistryError.runtimeMetadaUnavailable)
        }

        do {
            let moduleWrapper = createModuleResolutionWrapper(for: .xcmpallet, runtimeProvider: runtimeProvider)

            guard let chainAccount = wallet.fetch(for: chain.accountRequest()) else {
                throw ChainAccountFetchingError.accountNotExists
            }

            let operationFactory = try createExtrinsicOperationFactory(for: chain, chainAccount: chainAccount)

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

            let dependencies = [coderFactoryOperation] + moduleWrapper.allOperations + wrapper.dependencies

            return CompoundOperationWrapper(targetOperation: wrapper.targetOperation, dependencies: dependencies)
        } catch {
            return CompoundOperationWrapper.createWithError(error)
        }
    }

    func createOneOfFeeEstimationWrapper(
        for chain: ChainModel,
        message: Xcm.Message,
        info: XcmAssetTransferFee,
        baseWeight: BigUInt
    ) -> CompoundOperationWrapper<ExtrinsicFeeProtocol> {
        let maxWeight = baseWeight * BigUInt(message.instructionsCount)

        switch info.mode.type {
        case .proportional:
            let coefficient: BigUInt = info.mode.value.flatMap { BigUInt($0) } ?? 0
            let fee = coefficient * maxWeight / Self.weightPerSecond
            let model = ExtrinsicFee(amount: fee, payer: nil, weight: maxWeight)
            return CompoundOperationWrapper.createWithResult(model)
        case .standard:
            return createStardardFeeEstimationWrapper(chain: chain, message: message, maxWeight: maxWeight)
        }
    }

    func createDestinationFeeWrapper(
        for message: Xcm.Message,
        request: XcmUnweightedTransferRequest,
        xcmTransfers: XcmTransfers
    ) -> CompoundOperationWrapper<ExtrinsicFeeProtocol> {
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
    ) -> CompoundOperationWrapper<ExtrinsicFeeProtocol> {
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

    func createChainDeliveryFeeWrapper(
        for request: XcmDeliveryRequest,
        xcmTransfers: XcmTransfers
    ) -> CompoundOperationWrapper<ExtrinsicFeeProtocol> {
        do {
            guard
                let deliveryFee = try xcmTransfers.deliveryFee(from: request.fromChainId) else {
                return CompoundOperationWrapper.createWithResult(ExtrinsicFee.zero())
            }

            switch deliveryFee {
            case let .exponential(params):
                return createExponentialDeliveryFeeWrapper(
                    for: request,
                    params: params
                )
            case .undefined:
                return CompoundOperationWrapper.createWithResult(ExtrinsicFee.zero())
            }
        } catch {
            return CompoundOperationWrapper.createWithError(error)
        }
    }

    func createExponentialDeliveryFeeWrapper(
        for request: XcmDeliveryRequest,
        params: XcmDeliveryFee.Exponential
    ) -> CompoundOperationWrapper<ExtrinsicFeeProtocol> {
        guard let parachainId = request.toParachainId else {
            return CompoundOperationWrapper.createWithResult(ExtrinsicFee.zero())
        }

        guard let connection = chainRegistry.getConnection(for: request.fromChainId) else {
            let error = ChainRegistryError.connectionUnavailable
            return CompoundOperationWrapper.createWithError(error)
        }

        guard let runtimeProvider = chainRegistry.getRuntimeProvider(for: request.fromChainId) else {
            let error = ChainRegistryError.runtimeMetadaUnavailable
            return CompoundOperationWrapper.createWithError(error)
        }

        let opManager = OperationManager(operationQueue: operationQueue)
        let requestFactory = StorageRequestFactory(remoteFactory: StorageKeyFactory(), operationManager: opManager)

        let codingFactoryOperation = runtimeProvider.fetchCoderFactoryOperation()

        let factorWrapper: CompoundOperationWrapper<[StorageResponse<StringScaleMapper<BigUInt>>]>

        factorWrapper = requestFactory.queryItems(
            engine: connection,
            keyParams: { [StringScaleMapper(value: parachainId)] },
            factory: { try codingFactoryOperation.extractNoCancellableResultData() },
            storagePath: params.factorStoragePath
        )

        factorWrapper.addDependency(operations: [codingFactoryOperation])

        let messageTypeWrapper = xcmPalletQueryFactory.createXcmMessageTypeResolutionWrapper(
            for: runtimeProvider
        )

        let calculateOperation = ClosureOperation<ExtrinsicFeeProtocol> {
            let optFactor = try factorWrapper.targetOperation.extractNoCancellableResultData().first?.value
            let optMessageType = try messageTypeWrapper.targetOperation.extractNoCancellableResultData()
            let codingFactory = try codingFactoryOperation.extractNoCancellableResultData()

            guard
                let messageType = optMessageType,
                let factor = optFactor.map({ BigRational.fixedU128(value: $0.value) }) else {
                throw XcmTransferServiceError.deliveryFeeNotAvailable
            }

            let messageSize = try XcmMessageSerializer.serialize(
                message: request.message,
                type: messageType,
                codingFactory: codingFactory
            ).count

            let feeSize = params.sizeBase + BigUInt(messageSize) * params.sizeFactor
            let amount = factor.mul(value: feeSize)

            return ExtrinsicFee(amount: amount, payer: nil, weight: 0)
        }

        calculateOperation.addDependency(factorWrapper.targetOperation)
        calculateOperation.addDependency(messageTypeWrapper.targetOperation)

        let dependencies = [codingFactoryOperation] + factorWrapper.allOperations + messageTypeWrapper.allOperations

        return CompoundOperationWrapper(targetOperation: calculateOperation, dependencies: dependencies)
    }

    func createExecutionFeeWrapper(
        request: XcmUnweightedTransferRequest,
        xcmTransfers: XcmTransfers,
        feeMessages: XcmWeightMessages
    ) -> CompoundOperationWrapper<ExtrinsicFeeProtocol> {
        let destMsg = feeMessages.destination
        let destWrapper = createDestinationFeeWrapper(for: destMsg, request: request, xcmTransfers: xcmTransfers)

        var dependencies = destWrapper.allOperations

        let optReserveWrapper: CompoundOperationWrapper<ExtrinsicFeeProtocol>?

        if request.isNonReserveTransfer, let reserveMessage = feeMessages.reserve {
            let wrapper = createReserveFeeWrapper(
                for: reserveMessage,
                request: request,
                xcmTransfers: xcmTransfers
            )

            dependencies.append(contentsOf: wrapper.allOperations)

            optReserveWrapper = wrapper
        } else {
            optReserveWrapper = nil
        }

        let mergeOperation = ClosureOperation<ExtrinsicFeeProtocol> {
            let destFeeWeight = try destWrapper.targetOperation.extractNoCancellableResultData()
            let optReserveFeeWeight = try optReserveWrapper?.targetOperation.extractNoCancellableResultData()

            if let reserveFeeWeight = optReserveFeeWeight {
                let fee = destFeeWeight.amount + reserveFeeWeight.amount
                let weight = max(destFeeWeight.weight, reserveFeeWeight.weight)
                return ExtrinsicFee(amount: fee, payer: destFeeWeight.payer, weight: weight)
            } else {
                return destFeeWeight
            }
        }

        dependencies.forEach { mergeOperation.addDependency($0) }

        return CompoundOperationWrapper(targetOperation: mergeOperation, dependencies: dependencies)
    }

    func createDeliveryFeeWrapper(
        request: XcmUnweightedTransferRequest,
        xcmTransfers: XcmTransfers,
        feeMessages: XcmWeightMessages
    ) -> CompoundOperationWrapper<ExtrinsicFeeProtocol> {
        if request.isNonReserveTransfer, let reserveMessage = feeMessages.reserve {
            let originToReserveWrapper = createChainDeliveryFeeWrapper(
                for: .init(
                    message: reserveMessage,
                    fromChainId: request.origin.chain.chainId,
                    toParachainId: request.reserve.parachainId
                ),
                xcmTransfers: xcmTransfers
            )

            let reserveToDestWrapper = createChainDeliveryFeeWrapper(
                for: .init(
                    message: feeMessages.destination,
                    fromChainId: request.reserve.chain.chainId,
                    toParachainId: request.destination.parachainId
                ),
                xcmTransfers: xcmTransfers
            )

            let combiningOperation = ClosureOperation<ExtrinsicFeeProtocol> {
                let originToReserve = try originToReserveWrapper.targetOperation.extractNoCancellableResultData()
                let reserveToDestination = try reserveToDestWrapper.targetOperation.extractNoCancellableResultData()

                return ExtrinsicFee(
                    amount: originToReserve.amount + reserveToDestination.amount,
                    payer: originToReserve.payer,
                    weight: max(originToReserve.weight, reserveToDestination.weight)
                )
            }

            combiningOperation.addDependency(reserveToDestWrapper.targetOperation)
            combiningOperation.addDependency(originToReserveWrapper.targetOperation)

            return CompoundOperationWrapper(
                targetOperation: combiningOperation,
                dependencies: originToReserveWrapper.allOperations + reserveToDestWrapper.allOperations
            )
        } else {
            let originToDestinationWrapper = createChainDeliveryFeeWrapper(
                for: .init(
                    message: feeMessages.destination,
                    fromChainId: request.origin.chain.chainId,
                    toParachainId: request.destination.parachainId
                ),
                xcmTransfers: xcmTransfers
            )

            return originToDestinationWrapper
        }
    }
}
