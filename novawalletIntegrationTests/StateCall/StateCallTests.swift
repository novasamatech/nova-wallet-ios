import XCTest
@testable import novawallet
import SubstrateSdk

final class StateCallTests: XCTestCase {
    func testStateCall() {
        do {
            let inflation = try fetchStakingInflation(
                for: KnowChainId.polkadot,
                node: URL(string: "wss://polkadot-rpc.dwellir.com")!,
                at: nil
            )

            Logger.shared.debug("Inflation: \(inflation)")
        } catch {
            XCTFail("Error: \(error)")
        }
    }

    func testStateCallAtBlock() {
        do {
            let inflation = try fetchStakingInflation(
                for: KnowChainId.polkadot,
                node: URL(string: "wss://polkadot-rpc.dwellir.com")!,
                at: "0x9fe303d65c87f2a5673d4c413dbcb8aa447f2ec15130ab5cd87e7f04141e8ca0"
            )

            Logger.shared.debug("Inflation: \(inflation)")
        } catch {
            XCTFail("Error: \(error)")
        }
    }

    private func fetchStakingInflation(
        for chainId: ChainModel.Id,
        node: URL,
        at block: BlockHash?
    ) throws -> RuntimeApiInflationPrediction {
        let storageFacade = SubstrateStorageTestFacade()
        let chainRegistry = ChainRegistryFacade.setupForIntegrationTest(with: storageFacade)

        let runtimeProvider = try chainRegistry.getRuntimeProviderOrError(for: chainId)
        let connection = WebSocketEngine(urls: [node])!
        connection.connect()

        let stateCallFactory = StateCallRequestFactory()
        let operationQueue = OperationQueue()

        let fetchFactory = PolkadotInflationPredictionFactory(
            stateCallFactory: stateCallFactory,
            operationQueue: operationQueue
        )

        let wrapper = fetchFactory.createPredictionWrapper(
            for: connection,
            runtimeProvider: runtimeProvider,
            at: block
        )

        operationQueue.addOperations(wrapper.allOperations, waitUntilFinished: true)

        return try wrapper.targetOperation.extractNoCancellableResultData()
    }
}
