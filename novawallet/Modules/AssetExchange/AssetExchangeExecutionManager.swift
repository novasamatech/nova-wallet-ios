import Foundation
import Operation_iOS

enum AssetExchangeExecutionManagerError: Error {
    case invalidRouteDetails
    case feesOperationsMismatch
}

final class AssetExchangeExecutionManager {
    typealias ResultType = Balance

    let operations: [AssetExchangeAtomicOperationProtocol]
    let routeDetails: AssetExchangeFee
    let operationQueue: OperationQueue
    let syncQueue: DispatchQueue
    let logger: LoggerProtocol

    private var completionClosure: ((Result<ResultType, Error>) -> Void)?
    private let callStore = CancellableCallStore()
    private var isFinished: Bool = false

    init(
        operations: [AssetExchangeAtomicOperationProtocol],
        routeDetails: AssetExchangeFee,
        operationQueue: OperationQueue,
        logger: LoggerProtocol
    ) {
        self.operations = operations
        self.routeDetails = routeDetails
        self.operationQueue = operationQueue
        self.logger = logger

        syncQueue = DispatchQueue(label: "io.novawallet.asset.exchange.exec.\(UUID().uuidString)")
    }

    private func complete(with result: Result<ResultType, Error>) {
        isFinished = true
        completionClosure?(result)
    }

    private func calculateAmountInIncludingIntermediateFees() throws -> Balance {
        guard
            let firstSegment = operations.first,
            operations.count == routeDetails.fees.count else {
            throw AssetExchangeExecutionManagerError.feesOperationsMismatch
        }

        let totalSegments = operations.count
        let segmentsWithFee = zip(operations.suffix(totalSegments - 1), routeDetails.fees.suffix(totalSegments - 1))

        let newAmountOut: Balance? = try segmentsWithFee.reversed().reduce(nil) { newAmountOut, segmentWithFee in
            let segment = segmentWithFee.0
            let fee = segmentWithFee.1

            let curAmountIn = segment.swapLimit.amountIn
            let curAmountOut = segment.swapLimit.amountOut

            let totalFee = try fee.totalEnsuringSubmissionAsset()

            if let newAmountOut {
                return (newAmountOut * curAmountIn).divideByRoundingUp(curAmountOut) + totalFee
            } else {
                return curAmountIn + totalFee
            }
        }

        let firstSegmentIn = firstSegment.swapLimit.amountIn
        let firstSegmentOut = firstSegment.swapLimit.amountOut

        if let newAmountOut {
            return (newAmountOut * firstSegmentIn).divideByRoundingUp(firstSegmentOut)
        } else {
            return firstSegmentIn
        }
    }

    private func startFirstSegmentExecution() {
        do {
            guard
                let firstSegment = routeDetails.route.items.first,
                let firstFees = routeDetails.fees.first else {
                throw AssetExchangeExecutionManagerError.invalidRouteDetails
            }

            let amountIn = try calculateAmountInIncludingIntermediateFees()

            // TODO: Get rid when fee is fixed
            let feeAsset = firstSegment.edge.origin.assetId == AssetModel.utilityAssetId ? nil : firstSegment.edge.origin
            let holdingFee = try firstFees.totalToPayFromAmountEnsuring(asset: feeAsset)
            let amountInWithHolding = amountIn + holdingFee

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

        let wrapper = operations[index].executeWrapper(for: { amountIn })

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
        if currentSegment == operations.count - 1 {
            complete(with: .success(amountOut))
            return
        }

        let nextSegment = currentSegment + 1

        do {
            let leaveOnAccount = try routeDetails.fees[nextSegment].totalAmountToPayFromAccount()

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
