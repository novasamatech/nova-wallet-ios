import XCTest
@testable import novawallet
import SubstrateSdk

final class CallDispatchErrorDecoderTests: XCTestCase {
    func testHydraTradingLimitReachedError() throws {
        do {
            let status = try fetchStatus(
                for: "0x5eda7def38fc7afad4812bdb3a8961e85421bbb4afe51943dc5f1ffbfdf52a23",
                blockHash: "0xee7aba77eafe937cafbca64b245de1ff9bde876b58e83591e0331d4c135c1612",
                matchingEvents: nil,
                node: URL(string: "wss://hydration-rpc.n.dwellir.com")!,
                chainId: KnowChainId.hydra
            )

            Logger.shared.debug("Status: \(status)")
        } catch {
            XCTFail("Error: \(error)")
        }
    }

    func testHydraXcmTokenTransferError() throws {
        do {
            let status = try fetchStatus(
                for: "0xfdededd3f85f3f977c8cfa182237325c6d8929bae0a9180044e71677c8dad192",
                blockHash: "0x1c368b3d9903d9b57dc9c741b8e6b84787abe6b02f3c3a51b6d24d5ec88fccb9",
                matchingEvents: HydraSwapEventsMatcher(),
                node: URL(string: "wss://hydration-rpc.n.dwellir.com")!,
                chainId: KnowChainId.hydra
            )

            Logger.shared.debug("Status: \(status)")
        } catch {
            XCTFail("Error: \(error)")
        }
    }

    func testHydraSuccessSwap() throws {
        do {
            let status = try fetchStatus(
                for: "0x42ce5185c39ee2127a8f84ff9e71b0c8528e2b703ca2a609fd8940db5c93cfb2",
                blockHash: "0xb56343ae8a92a9fefed228e5e023ca034c83bbc4b43c74647bd063abcec599fb",
                matchingEvents: HydraSwapEventsMatcher(),
                node: URL(string: "wss://hydration-rpc.n.dwellir.com")!,
                chainId: KnowChainId.hydra
            )

            Logger.shared.debug("Status: \(status)")
        } catch {
            XCTFail("Error: \(error)")
        }
    }

    private func fetchStatus(
        for extrinsicHash: ExtrinsicHash,
        blockHash: BlockHash,
        matchingEvents: ExtrinsicEventsMatching?,
        node: URL,
        chainId: ChainModel.Id
    ) throws -> SubstrateExtrinsicStatus {
        let storageFacade = SubstrateStorageTestFacade()
        let chainRegistry = ChainRegistryFacade.setupForIntegrationTest(with: storageFacade)

        let runtimeService = try chainRegistry.getRuntimeProviderOrError(for: chainId)
        let connection = WebSocketEngine(urls: [node])!
        connection.connect()

        let operationQueue = OperationQueue()

        let statusService = ExtrinsicStatusService(
            connection: connection,
            runtimeProvider: runtimeService,
            eventsQueryFactory: BlockEventsQueryFactory(operationQueue: operationQueue),
            logger: Logger.shared
        )

        let wrapper = statusService.fetchExtrinsicStatusForHash(
            extrinsicHash,
            inBlock: blockHash,
            matchingEvents: matchingEvents
        )

        operationQueue.addOperations(wrapper.allOperations, waitUntilFinished: true)

        return try wrapper.targetOperation.extractNoCancellableResultData()
    }
}
