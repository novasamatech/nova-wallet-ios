import Foundation

final class HydraSwapExtrinsicService {
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

        extrinsicService.submit(
            builderClosure,
            payingIn: swapParams.params.newFeeCurrency,
            signer: signer,
            runningIn: queue,
            completion: closure
        )
    }
}

extension HydraSwapExtrinsicService: AssetConversionExtrinsicServiceProtocol {
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
                    self?.performSwapSubmission(
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
