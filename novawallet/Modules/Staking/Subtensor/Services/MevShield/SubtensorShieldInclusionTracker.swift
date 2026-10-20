import Foundation
import Operation_iOS
import SubstrateSdk
import BigInt

protocol SubtensorShieldInclusionTrackingProtocol {
    func createInnerStatusWrapper(
        for innerHash: ExtrinsicHash,
        carrierBlockHash: BlockHash,
        matchingEvents: ExtrinsicEventsMatching?
    ) -> CompoundOperationWrapper<SubstrateExtrinsicStatus?>
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
        static let pollsPerBlock = 4
    }

    func createHeaderOperation(for blockHash: BlockHash) -> BaseOperation<Block.Header> {
        JSONRPCListOperation<Block.Header>(
            engine: connection,
            method: RPCMethod.getBlockHeader,
            parameters: [blockHash]
        )
    }
}

extension SubtensorShieldInclusionTracker: SubtensorShieldInclusionTrackingProtocol {
    func createInnerStatusWrapper(
        for innerHash: ExtrinsicHash,
        carrierBlockHash: BlockHash,
        matchingEvents: ExtrinsicEventsMatching?
    ) -> CompoundOperationWrapper<SubstrateExtrinsicStatus?> {
        let headerOperation = createHeaderOperation(for: carrierBlockHash)
        let blockTimeWrapper = blockTimeOperationFactory.createExpectedBlockTimeWrapper(from: runtimeProvider)

        let search = SubtensorShieldInnerSearch(
            innerHash: innerHash,
            matchingEvents: matchingEvents,
            connection: connection,
            statusService: statusService,
            operationQueue: operationQueue
        )

        let searchOperation = AsyncClosureOperation<SubstrateExtrinsicStatus?>(
            operationClosure: { completion in
                let header = try headerOperation.extractNoCancellableResultData()
                let blockTime = try blockTimeWrapper.targetOperation.extractNoCancellableResultData()

                guard
                    let number = BigUInt.fromHexString(header.number),
                    let carrierBlock = BlockNumber(exactly: number) else {
                    throw BaseOperationError.unexpectedDependentResult
                }

                let windowLength = BlockNumber(SubtensorShieldConstants.eraPeriod)

                search.start(
                    from: carrierBlock,
                    blockHash: carrierBlockHash,
                    window: SubtensorShieldInnerSearch.Window(
                        deadline: carrierBlock + windowLength,
                        polls: Constants.pollsPerBlock * Int(windowLength + 1),
                        pollInterval: TimeInterval(blockTime).seconds
                    ),
                    completion: completion
                )
            },
            cancelationClosure: {
                search.cancel()
            }
        )

        searchOperation.addDependency(headerOperation)
        searchOperation.addDependency(blockTimeWrapper.targetOperation)

        return CompoundOperationWrapper(
            targetOperation: searchOperation,
            dependencies: [headerOperation] + blockTimeWrapper.allOperations
        )
    }
}
