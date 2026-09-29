import Foundation
import Operation_iOS
import SubstrateSdk

final class SubtensorResultChainFactory {
    let chain: ChainModel
    let connection: JSONRPCEngine
    let runtimeProvider: RuntimeCodingServiceProtocol
    let rootHoldFactory: SubtensorRootHoldFactoryProtocol
    let blockNumberOperationFactory: BlockNumberOperationFactoryProtocol
    let storageRequestFactory: StorageRequestFactoryProtocol

    init(
        chain: ChainModel,
        connection: JSONRPCEngine,
        runtimeProvider: RuntimeCodingServiceProtocol,
        rootHoldFactory: SubtensorRootHoldFactoryProtocol,
        blockNumberOperationFactory: BlockNumberOperationFactoryProtocol,
        storageRequestFactory: StorageRequestFactoryProtocol
    ) {
        self.chain = chain
        self.connection = connection
        self.runtimeProvider = runtimeProvider
        self.rootHoldFactory = rootHoldFactory
        self.blockNumberOperationFactory = blockNumberOperationFactory
        self.storageRequestFactory = storageRequestFactory
    }
}

extension SubtensorResultChainFactory: SubtensorResultChainFactoryProtocol {
    func createExpectedBlockTimeWrapper() -> CompoundOperationWrapper<BlockTime> {
        BlockTimeOperationFactory(chain: chain).createExpectedBlockTimeWrapper(from: runtimeProvider)
    }

    func createBlockTimestampWrapper(at blockHash: BlockHash) -> CompoundOperationWrapper<Date> {
        let blockHashData: Data

        do {
            blockHashData = try Data(hexString: blockHash)
        } catch {
            return .createWithError(error)
        }

        let codingFactoryOperation = runtimeProvider.fetchCoderFactoryOperation()

        let timestampWrapper: CompoundOperationWrapper<StorageResponse<StringScaleMapper<UInt64>>> =
            storageRequestFactory.queryItem(
                engine: connection,
                factory: { try codingFactoryOperation.extractNoCancellableResultData() },
                storagePath: .timestampNow,
                at: blockHashData
            )

        timestampWrapper.addDependency(operations: [codingFactoryOperation])

        let mapOperation = ClosureOperation<Date> {
            let response = try timestampWrapper.targetOperation.extractNoCancellableResultData()

            guard let milliseconds = response.value?.value else {
                throw BaseOperationError.unexpectedDependentResult
            }

            return Date(timeIntervalSince1970: TimeInterval(milliseconds) / 1000)
        }

        mapOperation.addDependency(timestampWrapper.targetOperation)

        return CompoundOperationWrapper(
            targetOperation: mapOperation,
            dependencies: [codingFactoryOperation] + timestampWrapper.allOperations
        )
    }

    func createRootHoldRemainingBlocksWrapper(
        coldkey: AccountId,
        hotkeys: [AccountId]
    ) -> CompoundOperationWrapper<UInt64> {
        let holdsWrapper = rootHoldFactory.createHoldsWrapper(coldkey: coldkey, hotkeys: hotkeys)
        let blockNumberWrapper = blockNumberOperationFactory.createWrapper(for: chain.chainId)

        let mapOperation = ClosureOperation<UInt64> {
            let holds = try holdsWrapper.targetOperation.extractNoCancellableResultData()
            let head = try UInt64(blockNumberWrapper.targetOperation.extractNoCancellableResultData())

            return holds.values.map { $0.remainingBlocks(at: head) }.max() ?? 0
        }

        mapOperation.addDependency(holdsWrapper.targetOperation)
        mapOperation.addDependency(blockNumberWrapper.targetOperation)

        return CompoundOperationWrapper(
            targetOperation: mapOperation,
            dependencies: holdsWrapper.allOperations + blockNumberWrapper.allOperations
        )
    }
}
