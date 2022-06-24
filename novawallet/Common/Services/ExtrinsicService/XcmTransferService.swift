import Foundation
import BigInt
import RobinHood
import SubstrateSdk

typealias XcmTrasferFeeResult = Result<FeeWithWeight, Error>
typealias XcmTransferEstimateFeeClosure = (XcmTrasferFeeResult) -> Void

typealias XcmSubmitExtrinsicResult = Result<String, Error>
typealias XcmExtrinsicSubmitClosure = (SubmitExtrinsicResult) -> Void

protocol XcmTransferServiceProtocol {
    func estimateOriginFee(
        request: XcmTransferRequest,
        xcmTransfers: XcmTransfers,
        maxWeight: BigUInt,
        runningIn queue: DispatchQueue,
        completion completionClosure: @escaping XcmTransferEstimateFeeClosure
    )

    func estimateDestinationTransferFee(
        request: XcmTransferRequest,
        xcmTransfers: XcmTransfers,
        runningIn queue: DispatchQueue,
        completion completionClosure: @escaping XcmTransferEstimateFeeClosure
    )

    func estimateReserveTransferFee(
        request: XcmTransferRequest,
        xcmTransfers: XcmTransfers,
        runningIn queue: DispatchQueue,
        completion completionClosure: @escaping XcmTransferEstimateFeeClosure
    )

    // Note: weight of the result contains max between reserve and destination weights
    func estimateCrossChainFee(
        request: XcmTransferRequest,
        xcmTransfers: XcmTransfers,
        runningIn queue: DispatchQueue,
        completion completionClosure: @escaping XcmTransferEstimateFeeClosure
    )

    func submit(
        request: XcmTransferRequest,
        xcmTransfers: XcmTransfers,
        maxWeight: BigUInt,
        signer: SigningWrapperProtocol,
        runningIn queue: DispatchQueue,
        completion completionClosure: @escaping XcmExtrinsicSubmitClosure
    )
}

enum XcmTransferServiceError: Error {
    case reserveFeeNotAvailable
    case noXcmPalletFound
}

final class XcmTransferService {
    static let weightPerSecond = BigUInt(1_000_000_000_000)

    let wallet: MetaAccountModel
    let chainRegistry: ChainRegistryProtocol
    let operationQueue: OperationQueue

    private lazy var xcmFactory = XcmTransferFactory()

    init(
        wallet: MetaAccountModel,
        chainRegistry: ChainRegistryProtocol,
        operationQueue: OperationQueue
    ) {
        self.wallet = wallet
        self.chainRegistry = chainRegistry
        self.operationQueue = operationQueue
    }

    private func createModuleResolutionWrapper(
        for transferType: XcmAssetTransfer.TransferType,
        runtimeProvider: RuntimeProviderProtocol
    ) -> CompoundOperationWrapper<String> {
        switch transferType {
        case .xtokens:
            return CompoundOperationWrapper.createWithResult("XTokens")
        case .xcmpallet:
            let coderFactoryOperation = runtimeProvider.fetchCoderFactoryOperation()

            let moduleResolutionOperation = ClosureOperation<String> {
                let metadata = try coderFactoryOperation.extractNoCancellableResultData().metadata
                guard let moduleName = Xcm.ExecuteCall.possibleModuleNames.first(
                    where: { metadata.getModuleIndex($0) != nil }
                ) else {
                    throw XcmTransferServiceError.noXcmPalletFound
                }

                return moduleName
            }

            moduleResolutionOperation.addDependency(coderFactoryOperation)

            return CompoundOperationWrapper(
                targetOperation: moduleResolutionOperation,
                dependencies: [coderFactoryOperation]
            )
        }
    }

    private func createOperationFactory(for chain: ChainModel) throws -> ExtrinsicOperationFactoryProtocol {
        guard let connection = chainRegistry.getConnection(for: chain.chainId) else {
            throw ChainRegistryError.connectionUnavailable
        }

        guard let runtimeProvider = chainRegistry.getRuntimeProvider(for: chain.chainId) else {
            throw ChainRegistryError.runtimeMetadaUnavailable
        }

        guard let chainAccount = wallet.fetch(for: chain.accountRequest()) else {
            throw ChainAccountFetchingError.accountNotExists
        }

        return ExtrinsicOperationFactory(
            accountId: chainAccount.accountId,
            chain: chain,
            cryptoType: chainAccount.cryptoType,
            runtimeRegistry: runtimeProvider,
            customExtensions: DefaultExtrinsicExtension.extensions,
            engine: connection
        )
    }

    private func createStardardFeeEstimationWrapper(
        chain: ChainModel,
        message: Xcm.Message,
        maxWeight: BigUInt
    ) -> CompoundOperationWrapper<FeeWithWeight> {
        guard let runtimeProvider = chainRegistry.getRuntimeProvider(for: chain.chainId) else {
            return CompoundOperationWrapper.createWithError(ChainRegistryError.runtimeMetadaUnavailable)
        }

        do {
            let moduleWrapper = createModuleResolutionWrapper(for: .xcmpallet, runtimeProvider: runtimeProvider)

            let operationFactory = try createOperationFactory(for: chain)

            let wrapper = operationFactory.estimateFeeOperation { builder in
                let moduleName = try moduleWrapper.targetOperation.extractNoCancellableResultData()
                let call = Xcm.ExecuteCall(message: message, maxWeight: maxWeight)
                return try builder.adding(call: call.runtimeCall(for: moduleName))
            }

            wrapper.addDependency(wrapper: moduleWrapper)

            let mapperOperation = ClosureOperation<FeeWithWeight> {
                let response = try wrapper.targetOperation.extractNoCancellableResultData()

                guard let fee = BigUInt(response.fee) else {
                    throw CommonError.dataCorruption
                }

                return FeeWithWeight(fee: fee, weight: maxWeight)
            }

            mapperOperation.addDependency(wrapper.targetOperation)

            let dependencies = moduleWrapper.allOperations + wrapper.allOperations

            return CompoundOperationWrapper(targetOperation: mapperOperation, dependencies: dependencies)
        } catch {
            return CompoundOperationWrapper.createWithError(error)
        }
    }

    private func createFeeEstimationWrapper(
        for chain: ChainModel,
        message: Xcm.Message,
        info: XcmAssetTransferFee,
        baseWeight: BigUInt
    ) -> CompoundOperationWrapper<FeeWithWeight> {
        let maxWeigth = baseWeight * BigUInt(message.instructionsCount)

        switch info.mode.type {
        case .proportional:
            let coefficient: BigUInt = info.mode.value.flatMap { BigUInt($0) } ?? 0
            let fee = coefficient * maxWeigth / Self.weightPerSecond
            let model = FeeWithWeight(fee: fee, weight: maxWeigth)
            return CompoundOperationWrapper.createWithResult(model)
        case .standard:
            return createStardardFeeEstimationWrapper(chain: chain, message: message, maxWeight: maxWeigth)
        }
    }

    private func createDestinationFeeWrapper(
        for message: Xcm.Message,
        request: XcmTransferRequest,
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

        return createFeeEstimationWrapper(
            for: request.destination.chain,
            message: message,
            info: feeInfo,
            baseWeight: baseWeight
        )
    }

    private func createReserveFeeWrapper(
        for message: Xcm.Message,
        request: XcmTransferRequest,
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

        return createFeeEstimationWrapper(
            for: request.reserve.chain,
            message: message,
            info: feeInfo,
            baseWeight: baseWeight
        )
    }

    private func createTransferWrapper(
        request: XcmTransferRequest,
        xcmTransfers: XcmTransfers,
        maxWeight: BigUInt
    ) -> CompoundOperationWrapper<ExtrinsicBuilderClosure> {
        guard let xcmTransfer = xcmTransfers.transfer(
            from: request.origin.chainAssetId,
            destinationChainId: request.destination.chain.chainId
        ) else {
            let error = XcmTransferFactoryError.noDestinationAssetFound(request.origin.chainAssetId)
            return CompoundOperationWrapper.createWithError(error)
        }

        guard let runtimeProvider = chainRegistry.getRuntimeProvider(for: request.origin.chain.chainId) else {
            return CompoundOperationWrapper.createWithError(ChainRegistryError.runtimeMetadaUnavailable)
        }

        do {
            let destinationAsset = try xcmFactory.createMultilocationAsset(
                from: request.origin,
                reserve: request.reserve.chain,
                destination: request.destination,
                amount: request.amount,
                xcmTransfers: xcmTransfers
            )

            let moduleResolutionWrapper = createModuleResolutionWrapper(
                for: xcmTransfer.type,
                runtimeProvider: runtimeProvider
            )

            let mapOperation = ClosureOperation<ExtrinsicBuilderClosure> {
                let module = try moduleResolutionWrapper.targetOperation.extractNoCancellableResultData()

                switch xcmTransfer.type {
                case .xtokens:
                    let call = Xcm.OrmlTransferCall(
                        asset: destinationAsset.asset,
                        destination: destinationAsset.location,
                        destinationWeight: maxWeight
                    )

                    return { builder in
                        try builder.adding(call: call.runtimeCall(for: module))
                    }
                case .xcmpallet:
                    let (destination, beneficiary) = destinationAsset.location.separatingDestinationBenifiary()
                    let assets = Xcm.VersionedMultiassets(versionedMultiasset: destinationAsset.asset)
                    let call = Xcm.PalletTransferCall(
                        destination: destination,
                        beneficiary: beneficiary,
                        assets: assets,
                        feeAssetItem: 0,
                        weightLimit: .limited(weight: UInt64(maxWeight))
                    )

                    return { builder in
                        try builder.adding(call: call.runtimeCall(for: module))
                    }
                }
            }

            mapOperation.addDependency(moduleResolutionWrapper.targetOperation)

            return CompoundOperationWrapper(
                targetOperation: mapOperation,
                dependencies: moduleResolutionWrapper.allOperations
            )

        } catch {
            return CompoundOperationWrapper.createWithError(error)
        }
    }
}

extension XcmTransferService: XcmTransferServiceProtocol {
    func estimateOriginFee(
        request: XcmTransferRequest,
        xcmTransfers: XcmTransfers,
        maxWeight: BigUInt,
        runningIn queue: DispatchQueue,
        completion completionClosure: @escaping XcmTransferEstimateFeeClosure
    ) {
        do {
            let callBuilderWrapper = createTransferWrapper(
                request: request,
                xcmTransfers: xcmTransfers,
                maxWeight: maxWeight
            )

            let operationFactory = try createOperationFactory(for: request.origin.chain)

            let feeWrapper = operationFactory.estimateFeeOperation { builder in
                let callClosure = try callBuilderWrapper.targetOperation.extractNoCancellableResultData()
                return try callClosure(builder)
            }

            feeWrapper.addDependency(wrapper: callBuilderWrapper)

            feeWrapper.targetOperation.completionBlock = {
                switch feeWrapper.targetOperation.result {
                case let .success(dispatchInfo):
                    if let feeWithWeight = FeeWithWeight(dispatchInfo: dispatchInfo) {
                        callbackClosureIfProvided(completionClosure, queue: queue, result: .success(feeWithWeight))
                    } else {
                        let error = CommonError.dataCorruption
                        callbackClosureIfProvided(completionClosure, queue: queue, result: .failure(error))
                    }
                case let .failure(error):
                    callbackClosureIfProvided(completionClosure, queue: queue, result: .failure(error))
                case .none:
                    let error = BaseOperationError.parentOperationCancelled
                    callbackClosureIfProvided(completionClosure, queue: queue, result: .failure(error))
                }
            }

            let operations = callBuilderWrapper.allOperations + feeWrapper.allOperations

            operationQueue.addOperations(operations, waitUntilFinished: false)
        } catch {
            callbackClosureIfProvided(completionClosure, queue: queue, result: .failure(error))
        }
    }

    func estimateDestinationTransferFee(
        request: XcmTransferRequest,
        xcmTransfers: XcmTransfers,
        runningIn queue: DispatchQueue,
        completion completionClosure: @escaping XcmTransferEstimateFeeClosure
    ) {
        do {
            let feeMessages = try xcmFactory.createWeightMessages(
                from: request.origin,
                reserve: request.reserve,
                destination: request.destination,
                amount: request.amount,
                xcmTransfers: xcmTransfers
            )

            let wrapper = createDestinationFeeWrapper(
                for: feeMessages.destination,
                request: request,
                xcmTransfers: xcmTransfers
            )

            wrapper.targetOperation.completionBlock = {
                switch wrapper.targetOperation.result {
                case let .some(result):
                    callbackClosureIfProvided(completionClosure, queue: queue, result: result)
                case .none:
                    let error = BaseOperationError.parentOperationCancelled
                    callbackClosureIfProvided(completionClosure, queue: queue, result: .failure(error))
                }
            }

            operationQueue.addOperations(wrapper.allOperations, waitUntilFinished: false)

        } catch {
            callbackClosureIfProvided(completionClosure, queue: queue, result: .failure(error))
        }
    }

    func estimateReserveTransferFee(
        request: XcmTransferRequest,
        xcmTransfers: XcmTransfers,
        runningIn queue: DispatchQueue,
        completion completionClosure: @escaping XcmTransferEstimateFeeClosure
    ) {
        do {
            let feeMessages = try xcmFactory.createWeightMessages(
                from: request.origin,
                reserve: request.reserve,
                destination: request.destination,
                amount: request.amount,
                xcmTransfers: xcmTransfers
            )

            if let reserveMessage = feeMessages.reserve {
                let wrapper = createReserveFeeWrapper(
                    for: reserveMessage,
                    request: request,
                    xcmTransfers: xcmTransfers
                )

                wrapper.targetOperation.completionBlock = {
                    switch wrapper.targetOperation.result {
                    case let .some(result):
                        callbackClosureIfProvided(completionClosure, queue: queue, result: result)
                    case .none:
                        let error = BaseOperationError.parentOperationCancelled
                        callbackClosureIfProvided(completionClosure, queue: queue, result: .failure(error))
                    }
                }

                operationQueue.addOperations(wrapper.allOperations, waitUntilFinished: false)
            } else {
                callbackClosureIfProvided(
                    completionClosure,
                    queue: queue,
                    result: .failure(XcmTransferServiceError.reserveFeeNotAvailable)
                )
            }
        } catch {
            callbackClosureIfProvided(completionClosure, queue: queue, result: .failure(error))
        }
    }

    func estimateCrossChainFee(
        request: XcmTransferRequest,
        xcmTransfers: XcmTransfers,
        runningIn queue: DispatchQueue,
        completion completionClosure: @escaping XcmTransferEstimateFeeClosure
    ) {
        do {
            let feeMessages = try xcmFactory.createWeightMessages(
                from: request.origin,
                reserve: request.reserve,
                destination: request.destination,
                amount: request.amount,
                xcmTransfers: xcmTransfers
            )

            let destWrapper = createDestinationFeeWrapper(
                for: feeMessages.destination,
                request: request,
                xcmTransfers: xcmTransfers
            )

            var dependencies = destWrapper.allOperations

            let optReserveWrapper: CompoundOperationWrapper<FeeWithWeight>?

            if let reserveMessage = feeMessages.reserve {
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

            let mergeOperation = ClosureOperation<FeeWithWeight> {
                let destFeeWeight = try destWrapper.targetOperation.extractNoCancellableResultData()
                let optReserveFeeWeight = try optReserveWrapper?.targetOperation.extractNoCancellableResultData()

                if let reserveFeeWeight = optReserveFeeWeight {
                    let fee = destFeeWeight.fee + reserveFeeWeight.fee
                    let weight = max(destFeeWeight.weight, reserveFeeWeight.weight)
                    return FeeWithWeight(fee: fee, weight: weight)
                } else {
                    return destFeeWeight
                }
            }

            dependencies.forEach { mergeOperation.addDependency($0) }

            mergeOperation.completionBlock = {
                switch mergeOperation.result {
                case let .some(result):
                    callbackClosureIfProvided(completionClosure, queue: queue, result: result)
                case .none:
                    let error = BaseOperationError.parentOperationCancelled
                    callbackClosureIfProvided(completionClosure, queue: queue, result: .failure(error))
                }
            }

            operationQueue.addOperations(dependencies + [mergeOperation], waitUntilFinished: false)

        } catch {
            callbackClosureIfProvided(completionClosure, queue: queue, result: .failure(error))
        }
    }

    func submit(
        request: XcmTransferRequest,
        xcmTransfers: XcmTransfers,
        maxWeight: BigUInt,
        signer: SigningWrapperProtocol,
        runningIn queue: DispatchQueue,
        completion completionClosure: @escaping XcmExtrinsicSubmitClosure
    ) {
        do {
            let callBuilderWrapper = createTransferWrapper(
                request: request,
                xcmTransfers: xcmTransfers,
                maxWeight: maxWeight
            )

            let operationFactory = try createOperationFactory(for: request.origin.chain)

            let submitWrapper = operationFactory.submit({ builder in
                let callClosure = try callBuilderWrapper.targetOperation.extractNoCancellableResultData()
                return try callClosure(builder)
            }, signer: signer)

            submitWrapper.addDependency(wrapper: callBuilderWrapper)

            submitWrapper.targetOperation.completionBlock = {
                switch submitWrapper.targetOperation.result {
                case let .some(result):
                    callbackClosureIfProvided(completionClosure, queue: queue, result: result)
                case .none:
                    let error = BaseOperationError.parentOperationCancelled
                    callbackClosureIfProvided(completionClosure, queue: queue, result: .failure(error))
                }
            }

            let operations = callBuilderWrapper.allOperations + submitWrapper.allOperations

            operationQueue.addOperations(operations, waitUntilFinished: false)
        } catch {
            callbackClosureIfProvided(completionClosure, queue: queue, result: .failure(error))
        }
    }
}
