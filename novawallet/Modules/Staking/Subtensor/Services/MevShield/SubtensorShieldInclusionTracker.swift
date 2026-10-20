import Foundation
import Operation_iOS
import SubstrateSdk
import BigInt

enum SubtensorShieldBlockRange {
    case fromCarrierBlock(BlockHash)
    case carrierEraFrom(BlockNumber)
}

protocol SubtensorShieldInclusionTrackingProtocol {
    func createFinalizedNumberWrapper() -> CompoundOperationWrapper<BlockNumber>

    func createInnerStatusWrapper(
        for innerHash: ExtrinsicHash,
        in range: SubtensorShieldBlockRange,
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
        static let averagePollsPerBlock = 4
    }

    struct SearchStart {
        let blockNumber: BlockNumber
        let blockHash: BlockHash?
        let deadline: BlockNumber
    }

    static func blockNumber(of header: Block.Header) throws -> BlockNumber {
        guard
            let number = BigUInt.fromHexString(header.number),
            let blockNumber = BlockNumber(exactly: number) else {
            throw BaseOperationError.unexpectedDependentResult
        }

        return blockNumber
    }

    func createHeaderWrapper(
        for blockHashClosure: @escaping () throws -> BlockHash
    ) -> CompoundOperationWrapper<Block.Header> {
        let headerOperation = JSONRPCListOperation<Block.Header>(engine: connection, method: RPCMethod.getBlockHeader)

        headerOperation.configurationBlock = {
            do {
                headerOperation.parameters = [try blockHashClosure()]
            } catch {
                headerOperation.result = .failure(error)
            }
        }

        return CompoundOperationWrapper(targetOperation: headerOperation)
    }

    func createSearchStartWrapper(for range: SubtensorShieldBlockRange) -> CompoundOperationWrapper<SearchStart> {
        let eraPeriod = BlockNumber(SubtensorShieldConstants.eraPeriod)

        switch range {
        case let .fromCarrierBlock(blockHash):
            let headerWrapper = createHeaderWrapper { blockHash }

            let startOperation = ClosureOperation<SearchStart> {
                let header = try headerWrapper.targetOperation.extractNoCancellableResultData()
                let blockNumber = try Self.blockNumber(of: header)

                return SearchStart(blockNumber: blockNumber, blockHash: blockHash, deadline: blockNumber + eraPeriod)
            }

            startOperation.addDependency(headerWrapper.targetOperation)

            return headerWrapper.insertingTail(operation: startOperation)
        case let .carrierEraFrom(blockNumber):
            return .createWithResult(
                SearchStart(blockNumber: blockNumber, blockHash: nil, deadline: blockNumber + eraPeriod - 1)
            )
        }
    }
}

extension SubtensorShieldInclusionTracker: SubtensorShieldInclusionTrackingProtocol {
    func createFinalizedNumberWrapper() -> CompoundOperationWrapper<BlockNumber> {
        let hashOperation = JSONRPCListOperation<String>(engine: connection, method: RPCMethod.getFinalizedBlockHash)

        let headerWrapper = createHeaderWrapper {
            try hashOperation.extractNoCancellableResultData()
        }

        headerWrapper.addDependency(operations: [hashOperation])

        let numberOperation = ClosureOperation<BlockNumber> {
            try Self.blockNumber(of: headerWrapper.targetOperation.extractNoCancellableResultData())
        }

        numberOperation.addDependency(headerWrapper.targetOperation)

        return headerWrapper
            .insertingHead(operations: [hashOperation])
            .insertingTail(operation: numberOperation)
    }

    func createInnerStatusWrapper(
        for innerHash: ExtrinsicHash,
        in range: SubtensorShieldBlockRange,
        matchingEvents: ExtrinsicEventsMatching?
    ) -> CompoundOperationWrapper<SubstrateExtrinsicStatus?> {
        let startWrapper = createSearchStartWrapper(for: range)
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
                let start = try startWrapper.targetOperation.extractNoCancellableResultData()
                let blockTime = try blockTimeWrapper.targetOperation.extractNoCancellableResultData()

                search.start(
                    from: start.blockNumber,
                    blockHash: start.blockHash,
                    window: SubtensorShieldInnerSearch.Window(
                        deadline: start.deadline,
                        pollBudget: Constants.averagePollsPerBlock * Int(start.deadline - start.blockNumber + 1),
                        pollInterval: TimeInterval(blockTime).seconds
                    ),
                    completion: completion
                )
            },
            cancelationClosure: {
                search.cancel()
            }
        )

        searchOperation.addDependency(startWrapper.targetOperation)
        searchOperation.addDependency(blockTimeWrapper.targetOperation)

        return CompoundOperationWrapper(
            targetOperation: searchOperation,
            dependencies: startWrapper.allOperations + blockTimeWrapper.allOperations
        )
    }
}
