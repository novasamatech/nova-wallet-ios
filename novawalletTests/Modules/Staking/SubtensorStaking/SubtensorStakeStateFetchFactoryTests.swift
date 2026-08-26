import XCTest
@testable import novawallet
import BigInt
import Operation_iOS
import Cuckoo

final class SubtensorStakeStateFetchFactoryTests: XCTestCase {
    let coldkey = Data(repeating: 1, count: 32)
    let hotkey = Data(repeating: 2, count: 32)
    let bestBlockHash = "0x1122334455667788112233445566778811223344556677881122334455667788"

    func testWrapperMergesPositionsAndPrices() throws {
        let stakeInfo = Self.stakeInfo(hotkey: hotkey, coldkey: coldkey, netuid: 5, stake: 2_000_000_000)

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
                    hotkeyEmissionPerTempo: 123,
                    totalHotkeyAlpha: nil,
                    isRegistered: true
                )
            ]
        )

        XCTAssertEqual(state.prices, [0: 1_000_000_000, 5: 500_000_000])
        XCTAssertEqual(state.totalStakeInRao, BigUInt(1_000_000_000))
    }

    func testBothRuntimeCallsPinnedToFetchedBlockHash() throws {
        let apiFactory = MockSubtensorApiOperationFactoryProtocol()

        stub(apiFactory) { stub in
            when(stub.createBestBlockHashWrapper()).thenReturn(
                CompoundOperationWrapper.createWithResult(bestBlockHash)
            )
            when(stub.createStakeInfoWrapper(for: any(), blockHash: any())).thenReturn(
                CompoundOperationWrapper.createWithResult([])
            )
            when(stub.createAlphaPricesWrapper(at: any())).thenReturn(
                CompoundOperationWrapper.createWithResult([])
            )
        }

        let factory = SubtensorStakeStateFetchFactory(
            operationFactory: apiFactory,
            operationQueue: OperationQueue()
        )

        _ = try fetchState(using: factory)

        let stakeInfoHashCaptor = ArgumentCaptor<BlockHash?>()
        let pricesHashCaptor = ArgumentCaptor<BlockHash?>()

        verify(apiFactory, times(1)).createStakeInfoWrapper(for: any(), blockHash: stakeInfoHashCaptor.capture())
        verify(apiFactory, times(1)).createAlphaPricesWrapper(at: pricesHashCaptor.capture())

        XCTAssertEqual(stakeInfoHashCaptor.value, bestBlockHash)
        XCTAssertEqual(pricesHashCaptor.value, bestBlockHash)
    }

    func testRootPositionWithoutPricesSucceeds() throws {
        let stakeInfo = Self.stakeInfo(hotkey: hotkey, coldkey: coldkey, netuid: 0, stake: 57_816_438)

        let factory = createFactory(
            stakeInfoResult: CompoundOperationWrapper.createWithResult([stakeInfo]),
            pricesResult: CompoundOperationWrapper.createWithResult([])
        )

        let state = try fetchState(using: factory)

        XCTAssertEqual(state.totalStakeInRao, BigUInt(57_816_438))
    }

    func testMissingAlphaPriceForHeldSubnetFailsFetch() {
        let stakeInfo = Self.stakeInfo(hotkey: hotkey, coldkey: coldkey, netuid: 7, stake: 1_000_000_000)

        let factory = createFactory(
            stakeInfoResult: CompoundOperationWrapper.createWithResult([stakeInfo]),
            pricesResult: CompoundOperationWrapper.createWithResult(
                [SubtensorStakingPallet.SubnetPrice(netuid: 3, price: 500_000_000)]
            )
        )

        XCTAssertThrowsError(try fetchState(using: factory)) { error in
            guard case let SubtensorStakeStateFetchFactoryError.missingAlphaPrice(netuid) = error else {
                return XCTFail("Unexpected error: \(error)")
            }

            XCTAssertEqual(netuid, 7)
        }
    }

    func testBlockHashFailurePropagates() {
        let apiFactory = MockSubtensorApiOperationFactoryProtocol()

        stub(apiFactory) { stub in
            when(stub.createBestBlockHashWrapper()).thenReturn(
                CompoundOperationWrapper.createWithError(CommonError.dataCorruption)
            )
            when(stub.createStakeInfoWrapper(for: any(), blockHash: any())).thenReturn(
                CompoundOperationWrapper.createWithResult([])
            )
            when(stub.createAlphaPricesWrapper(at: any())).thenReturn(
                CompoundOperationWrapper.createWithResult([])
            )
        }

        let factory = SubtensorStakeStateFetchFactory(
            operationFactory: apiFactory,
            operationQueue: OperationQueue()
        )

        XCTAssertThrowsError(try fetchState(using: factory))
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

    private static func stakeInfo(
        hotkey: AccountId,
        coldkey: AccountId,
        netuid: UInt16,
        stake: Balance
    ) -> SubtensorStakingPallet.StakeInfo {
        SubtensorStakingPallet.StakeInfo(
            hotkey: hotkey,
            coldkey: coldkey,
            netuid: netuid,
            stake: stake,
            locked: 0,
            emission: 123,
            taoEmission: 0,
            drain: 0,
            isRegistered: true
        )
    }

    private func createFactory(
        stakeInfoResult: CompoundOperationWrapper<[SubtensorStakingPallet.StakeInfo]>,
        pricesResult: CompoundOperationWrapper<[SubtensorStakingPallet.SubnetPrice]>
    ) -> SubtensorStakeStateFetchFactory {
        let apiFactory = MockSubtensorApiOperationFactoryProtocol()

        stub(apiFactory) { stub in
            when(stub.createBestBlockHashWrapper()).thenReturn(
                CompoundOperationWrapper.createWithResult(bestBlockHash)
            )
            when(stub.createStakeInfoWrapper(for: any(), blockHash: any())).thenReturn(stakeInfoResult)
            when(stub.createAlphaPricesWrapper(at: any())).thenReturn(pricesResult)
        }

        return SubtensorStakeStateFetchFactory(operationFactory: apiFactory, operationQueue: OperationQueue())
    }

    private func fetchState(
        using factory: SubtensorStakeStateFetchFactory
    ) throws -> Multistaking.SubtensorStakingState {
        let wrapper = factory.createStateWrapper(for: coldkey)

        OperationQueue().addOperations(wrapper.allOperations, waitUntilFinished: true)

        return try wrapper.targetOperation.extractNoCancellableResultData()
    }
}
