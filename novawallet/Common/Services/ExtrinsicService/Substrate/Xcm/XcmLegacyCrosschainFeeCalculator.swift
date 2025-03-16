import Foundation
import Operation_iOS
import SubstrateSdk
import BigInt

final class XcmLegacyCrosschainFeeCalculator {
    static let weightPerSecond = BigUInt(1_000_000_000_000)

    let chainRegistry: ChainRegistryProtocol
    let operationQueue: OperationQueue
    let wallet: MetaAccountModel
    let userStorageFacade: StorageFacadeProtocol
    let substrateStorageFacade: StorageFacadeProtocol
    let customFeeEstimatingFactory: ExtrinsicCustomFeeEstimatingFactoryProtocol?

    private lazy var xcmModelFactory = XcmModelFactory()
    private lazy var xcmPalletQueryFactory = XcmPalletMetadataQueryFactory()
    private lazy var xcmWeightMessagesFactory = XcmWeightMessagesFactory()
    private lazy var xTokensQueryFactory = XTokensMetadataQueryFactory()

    init(
        chainRegistry: ChainRegistryProtocol,
        operationQueue: OperationQueue,
        wallet: MetaAccountModel,
        userStorageFacade: StorageFacadeProtocol,
        substrateStorageFacade: StorageFacadeProtocol,
        customFeeEstimatingFactory: ExtrinsicCustomFeeEstimatingFactoryProtocol?
    ) {
        self.chainRegistry = chainRegistry
        self.operationQueue = operationQueue
        self.wallet = wallet
        self.userStorageFacade = userStorageFacade
        self.substrateStorageFacade = substrateStorageFacade
        self.customFeeEstimatingFactory = customFeeEstimatingFactory
    }

    func destinationExecutionFeeWrapper(
        request: XcmUnweightedTransferRequest,
        xcmTransfers: XcmLegacyTransfers
    ) -> CompoundOperationWrapper<XcmFeeModelProtocol> {
        do {
            let runtimeProvider = try chainRegistry.getRuntimeProviderOrError(
                for: request.destination.chain.chainId
            )

            let versionWrapper = xcmPalletQueryFactory.createLowestMultilocationVersionWrapper(for: runtimeProvider)

            let feeWrapper: CompoundOperationWrapper<XcmFeeModelProtocol>
            feeWrapper = OperationCombiningService.compoundNonOptionalWrapper(
                operationQueue: operationQueue
            ) {
                let version = try versionWrapper.targetOperation.extractNoCancellableResultData()

                let params = XcmWeightMessagesParams(
                    chainAsset: request.origin,
                    reserve: request.reserve,
                    destination: request.destination,
                    amount: request.amount,
                    xcmTransfers: xcmTransfers
                )

                let feeMessages = try self.xcmWeightMessagesFactory.createWeightMessages(
                    from: params,
                    version: version
                )

                return self.createDestinationFeeWrapper(
                    for: feeMessages.destination,
                    request: request,
                    xcmTransfers: xcmTransfers
                )
            }

            feeWrapper.addDependency(wrapper: versionWrapper)

            return feeWrapper.insertingHead(operations: versionWrapper.allOperations)

        } catch {
            return .createWithError(error)
        }
    }

    func reserveExecutionFeeWrapper(
        request: XcmUnweightedTransferRequest,
        xcmTransfers: XcmLegacyTransfers
    ) -> CompoundOperationWrapper<XcmFeeModelProtocol> {
        do {
            let runtimeProvider = try chainRegistry.getRuntimeProviderOrError(
                for: request.reserve.chain.chainId
            )

            let versionWrapper = xcmPalletQueryFactory.createLowestMultilocationVersionWrapper(for: runtimeProvider)

            let feeWrapper: CompoundOperationWrapper<XcmFeeModelProtocol>
            feeWrapper = OperationCombiningService.compoundNonOptionalWrapper(
                operationQueue: operationQueue
            ) {
                let version = try versionWrapper.targetOperation.extractNoCancellableResultData()

                let params = XcmWeightMessagesParams(
                    chainAsset: request.origin,
                    reserve: request.reserve,
                    destination: request.destination,
                    amount: request.amount,
                    xcmTransfers: xcmTransfers
                )

                let feeMessages = try self.xcmWeightMessagesFactory.createWeightMessages(
                    from: params,
                    version: version
                )

                guard let reserveMessage = feeMessages.reserve else {
                    throw XcmCrosschainFeeCalculatorError.reserveFeeNotAvailable
                }

                return self.createReserveFeeWrapper(
                    for: reserveMessage,
                    request: request,
                    xcmTransfers: xcmTransfers
                )
            }

            feeWrapper.addDependency(wrapper: versionWrapper)

            return feeWrapper.insertingHead(operations: versionWrapper.allOperations)

        } catch {
            return .createWithError(error)
        }
    }
}

private extension XcmLegacyCrosschainFeeCalculator {
    func createModuleResolutionWrapper(
        for transferType: XcmTransferType,
        runtimeProvider: RuntimeProviderProtocol
    ) -> CompoundOperationWrapper<String> {
        switch transferType {
        case .xtokens:
            return xTokensQueryFactory.createModuleNameResolutionWrapper(for: runtimeProvider)
        case .xcmpallet, .teleport, .xcmpalletTransferAssets:
            return xcmPalletQueryFactory.createModuleNameResolutionWrapper(for: runtimeProvider)
        case .unknown:
            return CompoundOperationWrapper.createWithError(XcmTransferTypeError.unknownType)
        }
    }

    func createExtrinsicOperationFactory(
        for chain: ChainModel,
        chainAccount: ChainAccountResponse
    ) throws -> ExtrinsicOperationFactoryProtocol {
        let connection = try chainRegistry.getConnectionOrError(for: chain.chainId)

        let runtimeProvider = try chainRegistry.getRuntimeProviderOrError(for: chain.chainId)

        if let customFeeEstimatingFactory {
            return ExtrinsicServiceFactory(
                runtimeRegistry: runtimeProvider,
                engine: connection,
                operationQueue: operationQueue,
                userStorageFacade: userStorageFacade,
                substrateStorageFacade: substrateStorageFacade
            ).createOperationFactory(
                account: chainAccount,
                chain: chain,
                customFeeEstimatingFactory: customFeeEstimatingFactory
            )
        } else {
            return ExtrinsicServiceFactory(
                runtimeRegistry: runtimeProvider,
                engine: connection,
                operationQueue: operationQueue,
                userStorageFacade: userStorageFacade,
                substrateStorageFacade: substrateStorageFacade
            ).createOperationFactory(account: chainAccount, chain: chain)
        }
    }

    func createStardardFeeEstimationWrapper(
        chain: ChainModel,
        message: Xcm.Message,
        maxWeight: BigUInt
    ) -> CompoundOperationWrapper<XcmFeeModelProtocol> {
        do {
            let runtimeProvider = try chainRegistry.getRuntimeProviderOrError(for: chain.chainId)
            let moduleWrapper = createModuleResolutionWrapper(for: .xcmpallet, runtimeProvider: runtimeProvider)
            let chainAccount = try wallet.fetchOrError(for: chain.accountRequest())

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
        xcmTransfers: XcmLegacyTransfers
    ) -> CompoundOperationWrapper<XcmFeeModelProtocol> {
        guard let feeInfo = xcmTransfers.destinationFee(
            from: request.origin.chainAssetId,
            to: request.destination.chain.chainId
        ) else {
            let error = XcmCrosschainFeeCalculatorError.noDestinationFee(
                origin: request.origin.chainAssetId,
                destination: request.destination.chain.chainId
            )

            return CompoundOperationWrapper.createWithError(error)
        }

        guard let baseWeight = xcmTransfers.baseWeight(for: request.destination.chain.chainId) else {
            let error = XcmCrosschainFeeCalculatorError.noBaseWeight(request.destination.chain.chainId)
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
        xcmTransfers: XcmLegacyTransfers
    ) -> CompoundOperationWrapper<XcmFeeModelProtocol> {
        guard let feeInfo = xcmTransfers.reserveFee(from: request.origin.chainAssetId) else {
            let error = XcmCrosschainFeeCalculatorError.noReserveFee(request.origin.chainAssetId)
            return CompoundOperationWrapper.createWithError(error)
        }

        guard let baseWeight = xcmTransfers.baseWeight(for: request.reserve.chain.chainId) else {
            let error = XcmCrosschainFeeCalculatorError.noBaseWeight(request.reserve.chain.chainId)
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
        xcmTransfers: XcmLegacyTransfers,
        sendingFromOrigin: Bool
    ) -> CompoundOperationWrapper<XcmFeeModelProtocol> {
        do {
            guard
                let deliveryFee = try xcmTransfers.deliveryFee(from: request.fromChainId) else {
                return CompoundOperationWrapper.createWithResult(XcmFeeModel.zero())
            }

            let optPrice: XcmDeliveryFee.Price?

            if request.toParachainId != nil {
                optPrice = deliveryFee.toParachain
            } else {
                optPrice = deliveryFee.toParent
            }

            guard let price = optPrice else {
                return CompoundOperationWrapper.createWithResult(XcmFeeModel.zero())
            }

            switch price {
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

    private func createExponentialFactorWrapper(
        for paraId: ParaId?,
        chainId: ChainModel.Id,
        params: XcmDeliveryFee.Exponential,
        dependingOn codingFactoryOperation: BaseOperation<RuntimeCoderFactoryProtocol>
    ) -> CompoundOperationWrapper<BigUInt> {
        guard let connection = chainRegistry.getConnection(for: chainId) else {
            let error = ChainRegistryError.connectionUnavailable
            return CompoundOperationWrapper.createWithError(error)
        }

        let opManager = OperationManager(operationQueue: operationQueue)
        let requestFactory = StorageRequestFactory(remoteFactory: StorageKeyFactory(), operationManager: opManager)

        if let paraId = paraId {
            let wrapper: CompoundOperationWrapper<[StorageResponse<StringScaleMapper<BigUInt>>]>

            wrapper = requestFactory.queryItems(
                engine: connection,
                keyParams: { [StringScaleMapper(value: paraId)] },
                factory: { try codingFactoryOperation.extractNoCancellableResultData() },
                storagePath: params.parachainFactorStoragePath
            )

            let mapOperation = ClosureOperation<BigUInt> {
                let optFactorValue = try wrapper.targetOperation.extractNoCancellableResultData().first?.value

                guard let factor = optFactorValue?.value else {
                    throw XcmCrosschainFeeCalculatorError.deliveryFeeNotAvailable
                }

                return factor
            }

            mapOperation.addDependency(wrapper.targetOperation)

            return CompoundOperationWrapper(targetOperation: mapOperation, dependencies: wrapper.allOperations)
        } else {
            let wrapper: CompoundOperationWrapper<StorageResponse<StringScaleMapper<BigUInt>>>
            wrapper = requestFactory.queryItem(
                engine: connection,
                factory: { try codingFactoryOperation.extractNoCancellableResultData() },
                storagePath: params.upwardFactorStoragePath
            )

            let mapOperation = ClosureOperation<BigUInt> {
                let optFactorValue = try wrapper.targetOperation.extractNoCancellableResultData().value

                guard let factor = optFactorValue?.value else {
                    throw XcmCrosschainFeeCalculatorError.deliveryFeeNotAvailable
                }

                return factor
            }

            mapOperation.addDependency(wrapper.targetOperation)

            return CompoundOperationWrapper(targetOperation: mapOperation, dependencies: wrapper.allOperations)
        }
    }

    func createExponentialDeliveryFeeWrapper(
        for request: XcmDeliveryRequest,
        params: XcmDeliveryFee.Exponential,
        sendingFromOrigin: Bool
    ) -> CompoundOperationWrapper<XcmFeeModelProtocol> {
        guard let runtimeProvider = chainRegistry.getRuntimeProvider(for: request.fromChainId) else {
            let error = ChainRegistryError.runtimeMetadaUnavailable
            return CompoundOperationWrapper.createWithError(error)
        }

        let codingFactoryOperation = runtimeProvider.fetchCoderFactoryOperation()

        let factorWrapper = createExponentialFactorWrapper(
            for: request.toParachainId,
            chainId: request.fromChainId,
            params: params,
            dependingOn: codingFactoryOperation
        )

        factorWrapper.addDependency(operations: [codingFactoryOperation])

        let messageTypeWrapper = xcmPalletQueryFactory.createXcmMessageTypeResolutionWrapper(
            for: runtimeProvider
        )

        let calculateOperation = ClosureOperation<XcmFeeModelProtocol> {
            let factorValue = try factorWrapper.targetOperation.extractNoCancellableResultData()
            let optMessageType = try messageTypeWrapper.targetOperation.extractNoCancellableResultData()
            let codingFactory = try codingFactoryOperation.extractNoCancellableResultData()

            guard let messageType = optMessageType else {
                throw XcmCrosschainFeeCalculatorError.deliveryFeeNotAvailable
            }

            let factor = BigRational.fixedU128(value: factorValue)

            let message = try XcmMessageSerializer.serialize(
                message: request.message,
                type: messageType,
                codingFactory: codingFactory
            )

            // TODO: Currently message doesn't contain setTopic command in the end. It will come with XCMv3 support
            let setTopicSize = 33
            let messageSize = message.count + setTopicSize

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
        xcmTransfers: XcmLegacyTransfers,
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
        xcmTransfers: XcmLegacyTransfers,
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

extension XcmLegacyCrosschainFeeCalculator: XcmCrosschainFeeCalculating {
    func crossChainFeeWrapper(
        request: XcmUnweightedTransferRequest,
        xcmTransfers: XcmLegacyTransfers
    ) -> CompoundOperationWrapper<XcmFeeModelProtocol> {
        do {
            let destinationRuntimeProvider = try chainRegistry.getRuntimeProviderOrError(
                for: request.destination.chain.chainId
            )

            let reserveRuntimeProvider = try chainRegistry.getRuntimeProviderOrError(
                for: request.reserve.chain.chainId
            )

            let destinationVersionWrapper = xcmPalletQueryFactory.createLowestMultilocationVersionWrapper(
                for: destinationRuntimeProvider
            )

            let reserveVersionWrapper = xcmPalletQueryFactory.createLowestMultilocationVersionWrapper(
                for: reserveRuntimeProvider
            )

            let feeWrapper: CompoundOperationWrapper<XcmFeeModelProtocol>
            feeWrapper = OperationCombiningService.compoundNonOptionalWrapper(
                operationQueue: operationQueue
            ) {
                let destinationVersion = try destinationVersionWrapper.targetOperation.extractNoCancellableResultData()
                let reserveVersion = try reserveVersionWrapper.targetOperation.extractNoCancellableResultData()

                let version = [destinationVersion, reserveVersion]
                    .compactMap { $0 }
                    .max()

                let params = XcmWeightMessagesParams(
                    chainAsset: request.origin,
                    reserve: request.reserve,
                    destination: request.destination,
                    amount: request.amount,
                    xcmTransfers: xcmTransfers
                )

                let feeMessages = try self.xcmWeightMessagesFactory.createWeightMessages(
                    from: params,
                    version: version
                )

                let executionFeeWrapper = self.createExecutionFeeWrapper(
                    request: request,
                    xcmTransfers: xcmTransfers,
                    feeMessages: feeMessages
                )

                let deliveryFeeWrapper = self.createDeliveryFeeWrapper(
                    request: request,
                    xcmTransfers: xcmTransfers,
                    feeMessages: feeMessages
                )

                let mergeOperation = ClosureOperation<XcmFeeModelProtocol> {
                    let executionFee = try executionFeeWrapper.targetOperation.extractNoCancellableResultData()
                    let deliveryFee = try deliveryFeeWrapper.targetOperation.extractNoCancellableResultData()

                    return XcmFeeModel.combine(executionFee, deliveryFee)
                }

                mergeOperation.addDependency(deliveryFeeWrapper.targetOperation)
                mergeOperation.addDependency(executionFeeWrapper.targetOperation)

                return deliveryFeeWrapper
                    .insertingHead(operations: executionFeeWrapper.allOperations)
                    .insertingTail(operation: mergeOperation)
            }

            feeWrapper.addDependency(wrapper: destinationVersionWrapper)
            feeWrapper.addDependency(wrapper: reserveVersionWrapper)

            return feeWrapper
                .insertingHead(operations: destinationVersionWrapper.allOperations)
                .insertingHead(operations: reserveVersionWrapper.allOperations)

        } catch {
            return .createWithError(error)
        }
    }
}
