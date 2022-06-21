import Foundation
import BigInt
import RobinHood
import SubstrateSdk

typealias XmcTrasferFeeResult = Result<FeeWithWeight, Error>
typealias XcmTransferEstimateFeeClosure = (XmcTrasferFeeResult) -> Void

protocol XcmTransferServiceProtocol {
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
}

enum XcmTransferServiceError: Error {
    case reserveFeeNotAvailable
}

final class XcmTransferService {
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

    private func createStardardFeeEstimationWrapper(
        chain: ChainModel,
        message: Xcm.Message,
        maxWeight: BigUInt
    ) -> CompoundOperationWrapper<FeeWithWeight> {
        guard let connection = chainRegistry.getConnection(for: chain.chainId) else {
            return CompoundOperationWrapper.createWithError(ChainRegistryError.connectionUnavailable)
        }

        guard let runtimeProvider = chainRegistry.getRuntimeProvider(for: chain.chainId) else {
            return CompoundOperationWrapper.createWithError(ChainRegistryError.runtimeMetadaUnavailable)
        }

        guard let chainAccount = wallet.fetch(for: chain.accountRequest()) else {
            return CompoundOperationWrapper.createWithError(ChainAccountFetchingError.accountNotExists)
        }

        let operationFactory = ExtrinsicOperationFactory(
            accountId: chainAccount.accountId,
            chain: chain,
            cryptoType: chainAccount.cryptoType,
            runtimeRegistry: runtimeProvider,
            customExtensions: DefaultExtrinsicExtension.extensions,
            engine: connection
        )

        let wrapper = operationFactory.estimateFeeOperation { builder in
            let call = Xcm.ExecuteCall(message: message, maxWeight: maxWeight)
            return try builder.adding(call: call.runtimeCall)
        }

        let mapperOperation = ClosureOperation<FeeWithWeight> {
            let response = try wrapper.targetOperation.extractNoCancellableResultData()

            guard let fee = BigUInt(response.fee) else {
                throw CommonError.dataCorruption
            }

            return FeeWithWeight(fee: fee, weight: maxWeight)
        }

        mapperOperation.addDependency(wrapper.targetOperation)

        return CompoundOperationWrapper(targetOperation: mapperOperation, dependencies: wrapper.allOperations)
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
            let coefficient: BigUInt = info.mode.coefficient.flatMap { BigUInt($0) } ?? 0
            let fee = coefficient * maxWeigth
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
}

extension XcmTransferService: XcmTransferServiceProtocol {
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
}
