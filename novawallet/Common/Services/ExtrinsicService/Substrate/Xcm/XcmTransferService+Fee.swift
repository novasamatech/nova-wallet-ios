import Foundation
import RobinHood
import BigInt
import SubstrateSdk

extension XcmTransferService {
    func createStardardFeeEstimationWrapper(
        chain: ChainModel,
        message: Xcm.Message,
        maxWeight: BigUInt
    ) -> CompoundOperationWrapper<XcmFeeModelProtocol> {
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

            let mappingOperation = ClosureOperation<XcmFeeModelProtocol> {
                let fee = try wrapper.targetOperation.extractNoCancellableResultData()

                return XcmFeeModel(senderPart: 0, holdingPart: fee.amount, weightLimit: fee.weight)
            }

            mappingOperation.addDependency(wrapper.targetOperation)

            let dependencies = [coderFactoryOperation] + moduleWrapper.allOperations + wrapper.allOperations

            return CompoundOperationWrapper(targetOperation: mappingOperation, dependencies: dependencies)
        } catch {
            return CompoundOperationWrapper.createWithError(error)
        }
    }

    func createOneOfFeeEstimationWrapper(
        for chain: ChainModel,
        message: Xcm.Message,
        info: XcmAssetTransferFee,
        baseWeight: BigUInt
    ) -> CompoundOperationWrapper<XcmFeeModelProtocol> {
        let maxWeight = baseWeight * BigUInt(message.instructionsCount)

        switch info.mode.type {
        case .proportional:
            let coefficient: BigUInt = info.mode.value.flatMap { BigUInt($0) } ?? 0
            let fee = coefficient * maxWeight / Self.weightPerSecond
            let model = XcmFeeModel(senderPart: 0, holdingPart: fee, weightLimit: maxWeight)
            return CompoundOperationWrapper.createWithResult(model)
        case .standard:
            return createStardardFeeEstimationWrapper(chain: chain, message: message, maxWeight: maxWeight)
        }
    }

    func createDestinationFeeWrapper(
        for message: Xcm.Message,
        request: XcmUnweightedTransferRequest,
        xcmTransfers: XcmTransfers
    ) -> CompoundOperationWrapper<XcmFeeModelProtocol> {
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
    ) -> CompoundOperationWrapper<XcmFeeModelProtocol> {
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
        xcmTransfers: XcmTransfers,
        sendingFromOrigin: Bool
    ) -> CompoundOperationWrapper<XcmFeeModelProtocol> {
        do {
            guard
                let deliveryFee = try xcmTransfers.deliveryFee(from: request.fromChainId) else {
                return CompoundOperationWrapper.createWithResult(XcmFeeModel.zero())
            }

            switch deliveryFee {
            case let .exponential(params):
                return createExponentialDeliveryFeeWrapper(
                    for: request,
                    params: params,
                    sendingFromOrigin: sendingFromOrigin
                )
            case .undefined:
                return CompoundOperationWrapper.createWithResult(XcmFeeModel.zero())
            }
        } catch {
            return CompoundOperationWrapper.createWithError(error)
        }
    }

    func createExponentialDeliveryFeeWrapper(
        for request: XcmDeliveryRequest,
        params: XcmDeliveryFee.Exponential,
        sendingFromOrigin: Bool
    ) -> CompoundOperationWrapper<XcmFeeModelProtocol> {
        guard let parachainId = request.toParachainId else {
            return CompoundOperationWrapper.createWithResult(XcmFeeModel.zero())
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

        let calculateOperation = ClosureOperation<XcmFeeModelProtocol> {
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

            let isSenderPart = params.isSenderPaysOriginDelivery && sendingFromOrigin

            return XcmFeeModel(
                senderPart: isSenderPart ? amount : 0,
                holdingPart: !isSenderPart ? amount : 0,
                weightLimit: 0
            )
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
    ) -> CompoundOperationWrapper<XcmFeeModelProtocol> {
        let destMsg = feeMessages.destination
        let destWrapper = createDestinationFeeWrapper(for: destMsg, request: request, xcmTransfers: xcmTransfers)

        var dependencies = destWrapper.allOperations

        let optReserveWrapper: CompoundOperationWrapper<XcmFeeModelProtocol>?

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

        let mergeOperation = ClosureOperation<XcmFeeModelProtocol> {
            let destFee = try destWrapper.targetOperation.extractNoCancellableResultData()
            let optReserveFee = try optReserveWrapper?.targetOperation.extractNoCancellableResultData()

            if let reserveFee = optReserveFee {
                return XcmFeeModel.combine(destFee, reserveFee)
            } else {
                return destFee
            }
        }

        dependencies.forEach { mergeOperation.addDependency($0) }

        return CompoundOperationWrapper(targetOperation: mergeOperation, dependencies: dependencies)
    }

    func createDeliveryFeeWrapper(
        request: XcmUnweightedTransferRequest,
        xcmTransfers: XcmTransfers,
        feeMessages: XcmWeightMessages
    ) -> CompoundOperationWrapper<XcmFeeModelProtocol> {
        if request.isNonReserveTransfer, let reserveMessage = feeMessages.reserve {
            let originToReserveWrapper = createChainDeliveryFeeWrapper(
                for: .init(
                    message: reserveMessage,
                    fromChainId: request.origin.chain.chainId,
                    toParachainId: request.reserve.parachainId
                ),
                xcmTransfers: xcmTransfers,
                sendingFromOrigin: true
            )

            let reserveToDestWrapper = createChainDeliveryFeeWrapper(
                for: .init(
                    message: feeMessages.destination,
                    fromChainId: request.reserve.chain.chainId,
                    toParachainId: request.destination.parachainId
                ),
                xcmTransfers: xcmTransfers,
                sendingFromOrigin: false
            )

            let combiningOperation = ClosureOperation<XcmFeeModelProtocol> {
                let originToReserve = try originToReserveWrapper.targetOperation.extractNoCancellableResultData()
                let reserveToDestination = try reserveToDestWrapper.targetOperation.extractNoCancellableResultData()

                return XcmFeeModel.combine(originToReserve, reserveToDestination)
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
                xcmTransfers: xcmTransfers,
                sendingFromOrigin: true
            )

            return originToDestinationWrapper
        }
    }
}
