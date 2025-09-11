import Foundation
import Operation_iOS
import SubstrateSdk
import BigInt

enum XcmLegacyCrosschainFeeCalculatorError: Error {
    case reserveFeeNotAvailable
    case unsupportedFee(XcmTransferMetadata.Fee)
    case deliveryFeeNotAvailable
}

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
    private lazy var xcmWeightMessagesFactory = XcmLegacyMessagesFactory()
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
        request: XcmUnweightedTransferRequest
    ) -> CompoundOperationWrapper<XcmFeeModelProtocol> {
        do {
            let runtimeProvider = try chainRegistry.getRuntimeProviderOrError(
                for: request.destination.chain.chainId
            )

            let versionWrapper = xcmPalletQueryFactory.createLowestXcmVersionWrapper(for: runtimeProvider)

            let feeWrapper: CompoundOperationWrapper<XcmFeeModelProtocol>
            feeWrapper = OperationCombiningService.compoundNonOptionalWrapper(
                operationQueue: operationQueue
            ) {
                let version = try versionWrapper.targetOperation.extractNoCancellableResultData()

                guard case let .legacy(feeParams) = request.metadata.fee else {
                    throw XcmLegacyCrosschainFeeCalculatorError.unsupportedFee(request.metadata.fee)
                }

                let params = XcmWeightMessagesParams(
                    origin: request.origin,
                    reserve: request.reserve,
                    destination: request.destination,
                    amount: request.amount,
                    feeParams: feeParams,
                    reserveParams: request.metadata.reserve
                )

                let feeMessages = try self.xcmWeightMessagesFactory.createWeightMessages(
                    from: params,
                    version: version
                )

                return self.createDestinationFeeWrapper(
                    for: feeMessages.destination,
                    request: request,
                    destinationFee: feeParams.destinationExecution
                )
            }

            feeWrapper.addDependency(wrapper: versionWrapper)

            return feeWrapper.insertingHead(operations: versionWrapper.allOperations)

        } catch {
            return .createWithError(error)
        }
    }

    func reserveExecutionFeeWrapper(
        request: XcmUnweightedTransferRequest
    ) -> CompoundOperationWrapper<XcmFeeModelProtocol> {
        do {
            let runtimeProvider = try chainRegistry.getRuntimeProviderOrError(
                for: request.reserve.chain.chainId
            )

            let versionWrapper = xcmPalletQueryFactory.createLowestXcmVersionWrapper(for: runtimeProvider)

            let feeWrapper: CompoundOperationWrapper<XcmFeeModelProtocol>
            feeWrapper = OperationCombiningService.compoundNonOptionalWrapper(
                operationQueue: operationQueue
            ) {
                let version = try versionWrapper.targetOperation.extractNoCancellableResultData()

                guard case let .legacy(feeParams) = request.metadata.fee else {
                    throw XcmLegacyCrosschainFeeCalculatorError.unsupportedFee(request.metadata.fee)
                }

                let params = XcmWeightMessagesParams(
                    origin: request.origin,
                    reserve: request.reserve,
                    destination: request.destination,
                    amount: request.amount,
                    feeParams: feeParams,
                    reserveParams: request.metadata.reserve
                )

                let feeMessages = try self.xcmWeightMessagesFactory.createWeightMessages(
                    from: params,
                    version: version
                )

                guard let reserveMessage = feeMessages.reserve, let reserveFee = feeParams.reserveExecution else {
                    throw XcmLegacyCrosschainFeeCalculatorError.reserveFeeNotAvailable
                }

                return self.createReserveFeeWrapper(
                    for: reserveMessage,
                    request: request,
                    reserveFee: reserveFee
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
        for transferType: XcmCallType,
        runtimeProvider: RuntimeProviderProtocol
    ) -> CompoundOperationWrapper<String> {
        switch transferType {
        case .xtokens:
            return xTokensQueryFactory.createModuleNameResolutionWrapper(for: runtimeProvider)
        case .xcmpallet, .teleport, .xcmpalletTransferAssets:
            return xcmPalletQueryFactory.createModuleNameResolutionWrapper(for: runtimeProvider)
        case .unknown:
            return CompoundOperationWrapper.createWithError(XcmCallTypeError.unknownType)
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
        message: XcmUni.VersionedMessage,
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

                return XcmFeeModel(senderPart: 0, holdingPart: fee.amount)
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
        message: XcmUni.VersionedMessage,
        info: XcmAssetTransferFee,
        baseWeight: BigUInt
    ) -> CompoundOperationWrapper<XcmFeeModelProtocol> {
        let maxWeight = baseWeight * BigUInt(message.entity.count)

        switch info.mode.type {
        case .proportional:
            let coefficient: BigUInt = info.mode.value.flatMap { BigUInt($0) } ?? 0
            let fee = coefficient * maxWeight / Self.weightPerSecond
            let model = XcmFeeModel(senderPart: 0, holdingPart: fee)
            return CompoundOperationWrapper.createWithResult(model)
        case .standard:
            return createStardardFeeEstimationWrapper(chain: chain, message: message, maxWeight: maxWeight)
        }
    }

    func createDestinationFeeWrapper(
        for message: XcmUni.VersionedMessage,
        request: XcmUnweightedTransferRequest,
        destinationFee: XcmTransferMetadata.LegacyFeeDetails
    ) -> CompoundOperationWrapper<XcmFeeModelProtocol> {
        createOneOfFeeEstimationWrapper(
            for: request.destination.chain,
            message: message,
            info: destinationFee.mode,
            baseWeight: destinationFee.baseWeight
        )
    }

    func createReserveFeeWrapper(
        for message: XcmUni.VersionedMessage,
        request: XcmUnweightedTransferRequest,
        reserveFee: XcmTransferMetadata.LegacyFeeDetails
    ) -> CompoundOperationWrapper<XcmFeeModelProtocol> {
        createOneOfFeeEstimationWrapper(
            for: request.reserve.chain,
            message: message,
            info: reserveFee.mode,
            baseWeight: reserveFee.baseWeight
        )
    }

    func createChainDeliveryFeeWrapper(
        for request: XcmDeliveryRequest,
        deliveryFee: XcmDeliveryFee?,
        sendingFromOrigin: Bool
    ) -> CompoundOperationWrapper<XcmFeeModelProtocol> {
        guard let deliveryFee else {
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
                    throw XcmLegacyCrosschainFeeCalculatorError.deliveryFeeNotAvailable
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
                    throw XcmLegacyCrosschainFeeCalculatorError.deliveryFeeNotAvailable
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
                throw XcmLegacyCrosschainFeeCalculatorError.deliveryFeeNotAvailable
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
                holdingPart: !isSenderPart ? amount : 0
            )
        }

        calculateOperation.addDependency(factorWrapper.targetOperation)
        calculateOperation.addDependency(messageTypeWrapper.targetOperation)

        let dependencies = [codingFactoryOperation] + factorWrapper.allOperations + messageTypeWrapper.allOperations

        return CompoundOperationWrapper(targetOperation: calculateOperation, dependencies: dependencies)
    }

    func createExecutionFeeWrapper(
        request: XcmUnweightedTransferRequest,
        feeMessages: XcmWeightMessages,
        feeParams: XcmTransferMetadata.LegacyFee
    ) -> CompoundOperationWrapper<XcmFeeModelProtocol> {
        let destMsg = feeMessages.destination
        let destWrapper = createDestinationFeeWrapper(
            for: destMsg,
            request: request,
            destinationFee: feeParams.destinationExecution
        )

        var dependencies = destWrapper.allOperations

        let optReserveWrapper: CompoundOperationWrapper<XcmFeeModelProtocol>?

        if
            request.isNonReserveTransfer,
            let reserveMessage = feeMessages.reserve,
            let reserveFee = feeParams.reserveExecution {
            let wrapper = createReserveFeeWrapper(
                for: reserveMessage,
                request: request,
                reserveFee: reserveFee
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
        feeMessages: XcmWeightMessages,
        feeParams: XcmTransferMetadata.LegacyFee
    ) -> CompoundOperationWrapper<XcmFeeModelProtocol> {
        if request.isNonReserveTransfer, let reserveMessage = feeMessages.reserve {
            let originToReserveWrapper = createChainDeliveryFeeWrapper(
                for: .init(
                    message: reserveMessage,
                    fromChainId: request.originChain.chainId,
                    toParachainId: request.reserve.parachainId
                ),
                deliveryFee: feeParams.originDelivery,
                sendingFromOrigin: true
            )

            let reserveToDestWrapper = createChainDeliveryFeeWrapper(
                for: .init(
                    message: feeMessages.destination,
                    fromChainId: request.reserve.chain.chainId,
                    toParachainId: request.destination.parachainId
                ),
                deliveryFee: feeParams.reserveDelivery,
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
                    fromChainId: request.originChain.chainId,
                    toParachainId: request.destination.parachainId
                ),
                deliveryFee: feeParams.originDelivery,
                sendingFromOrigin: true
            )

            return originToDestinationWrapper
        }
    }
}

extension XcmLegacyCrosschainFeeCalculator: XcmCrosschainFeeCalculating {
    func crossChainFeeWrapper(
        request: XcmUnweightedTransferRequest
    ) -> CompoundOperationWrapper<XcmFeeModelProtocol> {
        do {
            let destinationRuntimeProvider = try chainRegistry.getRuntimeProviderOrError(
                for: request.destination.chain.chainId
            )

            let reserveRuntimeProvider = try chainRegistry.getRuntimeProviderOrError(
                for: request.reserve.chain.chainId
            )

            let destinationVersionWrapper = xcmPalletQueryFactory.createLowestXcmVersionWrapper(
                for: destinationRuntimeProvider
            )

            let reserveVersionWrapper = xcmPalletQueryFactory.createLowestXcmVersionWrapper(
                for: reserveRuntimeProvider
            )

            let feeWrapper: CompoundOperationWrapper<XcmFeeModelProtocol>
            feeWrapper = OperationCombiningService.compoundNonOptionalWrapper(
                operationQueue: operationQueue
            ) {
                let destinationVersion = try destinationVersionWrapper.targetOperation.extractNoCancellableResultData()
                let reserveVersion = try reserveVersionWrapper.targetOperation.extractNoCancellableResultData()

                let version = max(destinationVersion, reserveVersion)

                guard case let .legacy(feeParams) = request.metadata.fee else {
                    throw XcmLegacyCrosschainFeeCalculatorError.unsupportedFee(request.metadata.fee)
                }

                let params = XcmWeightMessagesParams(
                    origin: request.origin,
                    reserve: request.reserve,
                    destination: request.destination,
                    amount: request.amount,
                    feeParams: feeParams,
                    reserveParams: request.metadata.reserve
                )

                let feeMessages = try self.xcmWeightMessagesFactory.createWeightMessages(
                    from: params,
                    version: version
                )

                let executionFeeWrapper = self.createExecutionFeeWrapper(
                    request: request,
                    feeMessages: feeMessages,
                    feeParams: feeParams
                )

                let deliveryFeeWrapper = self.createDeliveryFeeWrapper(
                    request: request,
                    feeMessages: feeMessages,
                    feeParams: feeParams
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
