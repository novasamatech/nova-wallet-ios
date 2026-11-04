import XCTest
@testable import novawallet
import Operation_iOS
import SubstrateSdk
import Cuckoo

final class HydraAaveFlowStateTests: XCTestCase {
    private let pairs = [HydraAave.TradePair(asset1: 5, asset2: 1001)]

    func testFailedDiscoveryIsRetriedOnNextUse() throws {
        let discoveryFactory = MockHydraAaveReservesDiscoveryFactoryProtocol()

        stub(discoveryFactory) { stub in
            when(stub.createPairsWrapper()).thenReturn(
                .createWithError(JSONRPCOperationError.timeout),
                .createWithResult(pairs)
            )
        }

        let flowState = try makeFlowState(discoveryFactory: discoveryFactory)

        XCTAssertThrowsError(try fetchPairs(from: flowState))
        XCTAssertEqual(try fetchPairs(from: flowState), pairs)

        verify(discoveryFactory, times(2)).createPairsWrapper()
    }

    func testDiscoveredPairsAreReusedOnNextUse() throws {
        let discoveryFactory = MockHydraAaveReservesDiscoveryFactoryProtocol()

        stub(discoveryFactory) { stub in
            when(stub.createPairsWrapper()).thenReturn(.createWithResult(pairs))
        }

        let flowState = try makeFlowState(discoveryFactory: discoveryFactory)

        XCTAssertEqual(try fetchPairs(from: flowState), pairs)
        XCTAssertEqual(try fetchPairs(from: flowState), pairs)

        verify(discoveryFactory, times(1)).createPairsWrapper()
    }
}

private extension HydraAaveFlowStateTests {
    func makeFlowState(discoveryFactory: HydraAaveReservesDiscoveryFactoryProtocol) throws -> HydraAaveFlowState {
        let apiFactory = MockHydraAaveTradeExecutorFactoryProtocol()

        stub(apiFactory) { stub in
            when(stub.createAaveTradePairs(for: any())).then { _ in .createWithResult([]) }
        }

        let codingFactory = try RuntimeCodingServiceStub.createWestendCodingFactory()
        let runtimeProvider = MockRuntimeProviderProtocol()

        stub(runtimeProvider) { stub in
            when(stub.fetchCoderFactoryOperation()).then { BaseOperation.createWithResult(codingFactory) }
        }

        return HydraAaveFlowState(
            account: AccountGenerator.generateSubstrateChainAccountResponse(for: KnowChainId.hydra),
            connection: MockTestJSONRPCEngine(),
            runtimeProvider: runtimeProvider,
            notificationsRegistrar: nil,
            apiFactory: apiFactory,
            reservesDiscoveryFactory: discoveryFactory,
            operationQueue: OperationQueue()
        )
    }

    func fetchPairs(from flowState: HydraAaveFlowState) throws -> [HydraAave.TradePair] {
        let wrapper = flowState.createPairsWrapper()

        OperationQueue().addOperations(wrapper.allOperations, waitUntilFinished: true)

        return try wrapper.targetOperation.extractNoCancellableResultData()
    }
}
