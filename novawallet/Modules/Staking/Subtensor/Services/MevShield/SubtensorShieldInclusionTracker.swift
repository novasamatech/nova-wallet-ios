import Foundation
import Operation_iOS
import SubstrateSdk

protocol SubtensorShieldInclusionTrackingProtocol {
    func createInnerScanWrapper(
        for innerHash: ExtrinsicHash,
        eraBirth: BlockNumber,
        matchingEvents: ExtrinsicEventsMatching?
    ) -> CompoundOperationWrapper<SubtensorShieldInnerScan>
}

final class SubtensorShieldInclusionTracker {
    let connection: JSONRPCEngine
    let runtimeProvider: RuntimeCodingServiceProtocol
    let statusService: ExtrinsicStatusServiceProtocol
    let blockTimeOperationFactory: BlockTimeOperationFactoryProtocol
    let operationQueue: OperationQueue

    init(
        connection: JSONRPCEngine,
        runtimeProvider: RuntimeCodingServiceProtocol,
        statusService: ExtrinsicStatusServiceProtocol,
        blockTimeOperationFactory: BlockTimeOperationFactoryProtocol,
        operationQueue: OperationQueue
    ) {
        self.connection = connection
        self.runtimeProvider = runtimeProvider
        self.statusService = statusService
        self.blockTimeOperationFactory = blockTimeOperationFactory
        self.operationQueue = operationQueue
    }
}

private extension SubtensorShieldInclusionTracker {
    enum Constants {
        static let pollsPerBlock = 2
        static let waitBudgetBlocks = 13
    }
}

extension SubtensorShieldInclusionTracker: SubtensorShieldInclusionTrackingProtocol {
    func createInnerScanWrapper(
        for innerHash: ExtrinsicHash,
        eraBirth: BlockNumber,
        matchingEvents: ExtrinsicEventsMatching?
    ) -> CompoundOperationWrapper<SubtensorShieldInnerScan> {
        let blockTimeWrapper = blockTimeOperationFactory.createExpectedBlockTimeWrapper(from: runtimeProvider)

        let search = SubtensorShieldInnerSearch(
            innerHash: innerHash,
            matchingEvents: matchingEvents,
            connection: connection,
            statusService: statusService,
            operationQueue: operationQueue
        )

        let searchOperation = AsyncClosureOperation<SubtensorShieldInnerScan>(
            operationClosure: { completion in
                let blockTime = try blockTimeWrapper.targetOperation.extractNoCancellableResultData()

                search.start(
                    window: SubtensorShieldInnerSearch.Window(
                        start: eraBirth,
                        deadline: eraBirth + BlockNumber(SubtensorShieldConstants.eraPeriod) - 1,
                        pollBudget: Constants.pollsPerBlock * Constants.waitBudgetBlocks,
                        pollInterval: TimeInterval(blockTime).seconds / TimeInterval(Constants.pollsPerBlock)
                    ),
                    completion: completion
                )
            },
            cancelationClosure: {
                search.cancel()
            }
        )

        searchOperation.addDependency(blockTimeWrapper.targetOperation)

        return blockTimeWrapper.insertingTail(operation: searchOperation)
    }
}
