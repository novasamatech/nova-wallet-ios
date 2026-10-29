import Foundation
import Operation_iOS
import SubstrateSdk

protocol SubtensorShieldInclusionOperationFactoryProtocol {
    func createInnerScanWrapper(
        for innerHash: ExtrinsicHash,
        carrierHash: ExtrinsicHash,
        eraBirth: BlockNumber,
        blockTiming: SubtensorShieldBlockTiming,
        matchingEvents: ExtrinsicEventsMatching?
    ) -> CompoundOperationWrapper<SubtensorShieldInnerScan>
}

final class SubtensorShieldInclusionOperationFactory {
    let connection: JSONRPCEngine
    let statusService: ExtrinsicStatusServiceProtocol
    let operationQueue: OperationQueue

    init(
        connection: JSONRPCEngine,
        statusService: ExtrinsicStatusServiceProtocol,
        operationQueue: OperationQueue
    ) {
        self.connection = connection
        self.statusService = statusService
        self.operationQueue = operationQueue
    }
}

private extension SubtensorShieldInclusionOperationFactory {
    enum Constants {
        static let pollsPerBlock = 2
    }
}

extension SubtensorShieldInclusionOperationFactory: SubtensorShieldInclusionOperationFactoryProtocol {
    func createInnerScanWrapper(
        for innerHash: ExtrinsicHash,
        carrierHash: ExtrinsicHash,
        eraBirth: BlockNumber,
        blockTiming: SubtensorShieldBlockTiming,
        matchingEvents: ExtrinsicEventsMatching?
    ) -> CompoundOperationWrapper<SubtensorShieldInnerScan> {
        let search = SubtensorShieldInnerSearch(
            innerHash: innerHash,
            carrierHash: carrierHash,
            matchingEvents: matchingEvents,
            connection: connection,
            statusService: statusService,
            operationQueue: operationQueue
        )

        let window = SubtensorShieldInnerSearch.Window(
            start: eraBirth,
            deadline: eraBirth + BlockNumber(SubtensorShieldConstants.eraPeriod) - 1,
            pollBudget: Constants.pollsPerBlock * Int(SubtensorShieldConstants.scanWaitBlocks),
            pollInterval: blockTiming.blockInterval / TimeInterval(Constants.pollsPerBlock)
        )

        let searchOperation = AsyncClosureOperation<SubtensorShieldInnerScan>(
            operationClosure: { completion in
                search.start(window: window, completion: completion)
            },
            cancelationClosure: {
                search.cancel()
            }
        )

        return CompoundOperationWrapper(targetOperation: searchOperation)
    }
}
