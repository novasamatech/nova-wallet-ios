import XCTest
@testable import novawallet
import BigInt
import Operation_iOS
import Cuckoo

final class SubtensorStakeStateFetchFactoryTests: XCTestCase {
    let coldkey = Data(repeating: 1, count: 32)
    let hotkey = Data(repeating: 2, count: 32)

    func testWrapperMergesPositionsAndPrices() throws {
        let stakeInfo = SubtensorStakingPallet.StakeInfo(
            hotkey: hotkey,
            coldkey: coldkey,
            netuid: 5,
            stake: 2_000_000_000,
            locked: 0,
            emission: 123,
            taoEmission: 0,
            drain: 0,
            isRegistered: true
        )

        let prices = [
            SubtensorStakingPallet.SubnetPrice(netuid: 0, price: 1_000_000_000),
            SubtensorStakingPallet.SubnetPrice(netuid: 5, price: 500_000_000)
        ]

        let factory = createFactory(
            stakeInfoResult: CompoundOperationWrapper.createWithResult([stakeInfo]),
            pricesResult: CompoundOperationWrapper.createWithResult(prices)
        )

        let state = try fetchState(using: factory)

        XCTAssertEqual(
            state.positions,
            [
                SubtensorStakingPosition(
                    hotkey: hotkey,
                    netuid: 5,
                    stakeAlpha: 2_000_000_000,
                    emissionPerTempo: 123,
                    isRegistered: true
                )
            ]
        )

        XCTAssertEqual(state.prices, [0: 1_000_000_000, 5: 500_000_000])
        XCTAssertEqual(state.totalStakeInRao, BigUInt(1_000_000_000))
    }

    func testStakeInfoFailurePropagates() {
        let factory = createFactory(
            stakeInfoResult: CompoundOperationWrapper.createWithError(CommonError.dataCorruption),
            pricesResult: CompoundOperationWrapper.createWithResult([])
        )

        XCTAssertThrowsError(try fetchState(using: factory))
    }

    func testPricesFailurePropagates() {
        let factory = createFactory(
            stakeInfoResult: CompoundOperationWrapper.createWithResult([]),
            pricesResult: CompoundOperationWrapper.createWithError(CommonError.dataCorruption)
        )

        XCTAssertThrowsError(try fetchState(using: factory))
    }

    private func createFactory(
        stakeInfoResult: CompoundOperationWrapper<[SubtensorStakingPallet.StakeInfo]>,
        pricesResult: CompoundOperationWrapper<[SubtensorStakingPallet.SubnetPrice]>
    ) -> SubtensorStakeStateFetchFactory {
        let apiFactory = MockSubtensorApiOperationFactoryProtocol()

        stub(apiFactory) { stub in
            when(stub.createStakeInfoWrapper(for: any(), blockHash: any())).thenReturn(stakeInfoResult)
            when(stub.createAlphaPricesWrapper(at: any())).thenReturn(pricesResult)
        }

        return SubtensorStakeStateFetchFactory(operationFactory: apiFactory)
    }

    private func fetchState(
        using factory: SubtensorStakeStateFetchFactory
    ) throws -> Multistaking.SubtensorStakingState {
        let wrapper = factory.createStateWrapper(for: coldkey)

        OperationQueue().addOperations(wrapper.allOperations, waitUntilFinished: true)

        return try wrapper.targetOperation.extractNoCancellableResultData()
    }
}
