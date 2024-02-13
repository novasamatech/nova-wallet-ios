import Foundation

final class HydraExtrinsicService {
    let extrinsicService: ExtrinsicServiceProtocol
    let conversionExtrinsicFactory: HydraExtrinsicOperationFactoryProtocol
    let operationQueue: OperationQueue
    let workQueue: DispatchQueue
    let logger: LoggerProtocol

    init(
        extrinsicService: ExtrinsicServiceProtocol,
        conversionExtrinsicFactory: HydraExtrinsicOperationFactoryProtocol,
        operationQueue: OperationQueue,
        workQueue: DispatchQueue = .global(),
        logger: LoggerProtocol = Logger.shared
    ) {
        self.extrinsicService = extrinsicService
        self.conversionExtrinsicFactory = conversionExtrinsicFactory
        self.operationQueue = operationQueue
        self.workQueue = workQueue
        self.logger = logger
    }

    private func cancelSubscription(for subscriptionId: UInt16?) {
        if let subscriptionId = subscriptionId {
            extrinsicService.cancelExtrinsicWatch(for: subscriptionId)
        }
    }

    private func performSwapSubmission(
        for swapParams: HydraSwapParams,
        signer: SigningWrapperProtocol,
        runCompletionIn queue: DispatchQueue,
        completion closure: @escaping ExtrinsicSubmitClosure
    ) {
        let builderClosure: ExtrinsicBuilderClosure = { builder in
            try HydraExtrinsicConverter.addingOperation(
                from: swapParams,
                builder: builder
            )
        }

        extrinsicService.submit(builderClosure, signer: signer, runningIn: queue, completion: closure)
    }

    private func performSubmission(
        for swapParams: HydraSwapParams,
        signer: SigningWrapperProtocol,
        runCompletionIn queue: DispatchQueue,
        completion closure: @escaping ExtrinsicSubmitClosure
    ) {
        guard swapParams.params.shouldSetFeeCurrency else {
            performSwapSubmission(
                for: swapParams,
                signer: signer,
                runCompletionIn: queue,
                completion: closure
            )
            return
        }

        var extrinsicSubscriptionId: UInt16?

        let builderClosure: ExtrinsicBuilderClosure = { builder in
            try HydraExtrinsicConverter.addingSetCurrencyCall(
                from: swapParams,
                builder: builder
            )
        }

        let subscriptionIdClosure: ExtrinsicSubscriptionIdClosure = { subscriptionId in
            extrinsicSubscriptionId = subscriptionId
            return true
        }

        let notificationClosure: ExtrinsicSubscriptionStatusClosure = { [weak self] result in
            switch result {
            case let .success(status):
                self?.logger.debug("Currency change status: \(status)")

                if case .inBlock = status {
                    self?.cancelSubscription(for: extrinsicSubscriptionId)
                    self?.performSwapSubmission(
                        for: swapParams,
                        signer: signer,
                        runCompletionIn: .main,
                        completion: closure
                    )
                }
            case let .failure(error):
                self?.logger.debug("Currency change failed: \(error)")

                self?.cancelSubscription(for: extrinsicSubscriptionId)

                dispatchInQueueWhenPossible(queue) {
                    closure(.failure(error))
                }
            }
        }

        extrinsicService.submitAndWatch(
            builderClosure,
            signer: signer,
            runningIn: workQueue,
            subscriptionIdClosure: subscriptionIdClosure,
            notificationClosure: notificationClosure
        )
    }
}

extension HydraExtrinsicService: AssetConversionExtrinsicServiceProtocol {
    func submit(
        callArgs: AssetConversion.CallArgs,
        feeAsset: ChainAsset,
        signer: SigningWrapperProtocol,
        runCompletionIn queue: DispatchQueue,
        completion closure: @escaping ExtrinsicSubmitClosure
    ) {
        let swapParamsWrapper = conversionExtrinsicFactory.createOperationWrapper(
            for: feeAsset,
            callArgs: callArgs
        )

        execute(
            wrapper: swapParamsWrapper,
            inOperationQueue: operationQueue,
            runningCallbackIn: workQueue,
            callbackClosure: { [weak self] result in
                self?.logger.debug("Extrinsic params: \(result)")

                switch result {
                case let .success(swapParams):
                    self?.performSubmission(
                        for: swapParams,
                        signer: signer,
                        runCompletionIn: queue,
                        completion: closure
                    )
                case let .failure(error):
                    dispatchInQueueWhenPossible(queue) {
                        closure(.failure(error))
                    }
                }
            }
        )
    }
}
