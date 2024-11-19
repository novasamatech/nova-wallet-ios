import Foundation
import Operation_iOS

enum AssetExchangeExecutionManagerError: Error {
    case invalidRouteDetails
}

final class AssetExchangeExecutionManager {
    typealias ResultType = Balance

    let routeDetails: AssetExchangeFee
    let operationQueue: OperationQueue
    let syncQueue: DispatchQueue
    let logger: LoggerProtocol

    private var completionClosure: ((Result<ResultType, Error>) -> Void)?
    private let callStore = CancellableCallStore()
    private var isFinished: Bool = false

    init(
        routeDetails: AssetExchangeFee,
        operationQueue: OperationQueue,
        logger: LoggerProtocol
    ) {
        self.routeDetails = routeDetails
        self.operationQueue = operationQueue
        self.logger = logger

        syncQueue = DispatchQueue(label: "io.novawallet.asset.exchange.exec.\(UUID().uuidString)")
    }

    private func complete(with result: Result<ResultType, Error>) {
        isFinished = true
        completionClosure?(result)
    }

    private func startFirstSegmentExecution() {
        do {
            guard
                let firstSegment = routeDetails.route.items.first,
                let firstFees = routeDetails.operationFees.first else {
                throw AssetExchangeExecutionManagerError.invalidRouteDetails
            }

            let amountIn = firstSegment.amountIn(for: routeDetails.route.direction)
            let amountInWithFee = amountIn + routeDetails.intermediateFeesInAssetIn

            let holdingFee = try firstFees.totalToPayFromAmountEnsuring(asset: firstSegment.edge.origin)
            let amountInWithHolding = amountInWithFee + holdingFee

            executeSegment(at: 0, amountIn: amountInWithHolding)
        } catch {
            logger.error("Failed first segment processing: \(error)")
            complete(with: .failure(error))
        }
    }

    private func executeSegment(at index: Int, amountIn: Balance) {
        guard !isFinished else {
            return
        }

        logger.debug("Executing swap \(index)")

        let shouldReplaceBuyWithSell = index != 0
        let swapLimit = routeDetails.operations[index].swapLimit.replacingAmountIn(
            amountIn,
            shouldReplaceBuyWithSell: shouldReplaceBuyWithSell
        )

        let wrapper = routeDetails.operations[index].executeWrapper(for: swapLimit)

        executeCancellable(
            wrapper: wrapper,
            inOperationQueue: operationQueue,
            backingCallIn: callStore,
            runningCallbackIn: syncQueue
        ) { [weak self] result in
            switch result {
            case let .success(amountOut):
                self?.logger.debug("Executed swap \(index): \(String(amountOut))")
                self?.correctAmountAndExecuteNext(after: index, amountOut: amountOut)
            case let .failure(error):
                self?.logger.error("Failed swap exec \(index): \(error)")
                self?.complete(with: .failure(error))
            }
        }
    }

    private func correctAmountAndExecuteNext(after currentSegment: Int, amountOut: Balance) {
        if currentSegment == routeDetails.operations.count - 1 {
            complete(with: .success(amountOut))
            return
        }

        let nextSegment = currentSegment + 1

        do {
            let leaveOnAccount = try routeDetails.operationFees[nextSegment].totalAmountToPayFromAccount()

            logger.debug("Amount for fee: \(Balance(leaveOnAccount))")

            let correctedAmount = amountOut.subtractOrZero(leaveOnAccount)

            executeSegment(at: nextSegment, amountIn: correctedAmount)
        } catch {
            logger.error("Failed segment processing \(nextSegment): \(error)")
            complete(with: .failure(error))
        }
    }
}

extension AssetExchangeExecutionManager: Longrunable {
    func start(with completionClosure: @escaping (Result<ResultType, Error>) -> Void) {
        syncQueue.async {
            guard !self.isFinished else {
                return
            }

            self.completionClosure = completionClosure

            self.startFirstSegmentExecution()
        }
    }

    func cancel() {
        syncQueue.async {
            guard !self.isFinished else {
                return
            }

            self.isFinished = true
            self.callStore.cancel()
        }
    }
}
