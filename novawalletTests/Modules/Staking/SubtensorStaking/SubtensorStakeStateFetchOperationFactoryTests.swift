import XCTest
@testable import novawallet
import BigInt
import Operation_iOS
import Cuckoo

final class SubtensorStakeStateFetchOperationFactoryTests: XCTestCase {
    let coldkey = Data(repeating: 1, count: 32)
    let hotkey = Data(repeating: 2, count: 32)
    let bestBlockHash = "0x1122334455667788112233445566778811223344556677881122334455667788"

    func testStateMapsStakeInfoAndAvailabilityAtPinnedBlock() throws {
        let availabilities: [SubtensorPallet.ColdkeyStakeAvailability] =
            try SubtensorFixtureDecoding.decodeRuntimeApiResult(
                from: "0x04" + String(repeating: "01", count: 32) +
                    "080000dad5c80d00dad5c80d070003005ed0b202286bee0300943577",
                path: SubtensorPallet.stakeAvailabilityForColdkeysApi
            )
        let apiFactory = createApiFactory(
            stakeInfoResult: .createWithResult([
                stakeInfo(netuid: 7, stake: 3_000_000_000),
                stakeInfo(netuid: 0, stake: 57_816_438)
            ]),
            availabilities: availabilities
        )

        let state = try fetchState(using: apiFactory)

        XCTAssertEqual(state.positions, [
            position(netuid: 7, stake: 3_000_000_000),
            position(netuid: 0, stake: 57_816_438)
        ])
        XCTAssertEqual(state.rootStakeInRao, BigUInt(57_816_438))
        XCTAssertEqual(state.availability, [
            0: SubtensorPallet.StakeAvailability(available: 57_816_438),
            7: SubtensorPallet.StakeAvailability(available: 2_000_000_000)
        ])

        let stakeInfoHashCaptor = ArgumentCaptor<BlockHash?>()
        verify(apiFactory, times(1)).createStakeInfoWrapper(for: any(), blockHash: stakeInfoHashCaptor.capture())
        XCTAssertEqual(stakeInfoHashCaptor.value, bestBlockHash)

        let netuidsCaptor = ArgumentCaptor<[UInt16]>()
        let availabilityHashCaptor = ArgumentCaptor<BlockHash?>()
        verify(apiFactory, times(1)).createStakeAvailabilityWrapper(
            for: any(),
            netuids: netuidsCaptor.capture(),
            blockHash: availabilityHashCaptor.capture()
        )
        XCTAssertEqual(netuidsCaptor.value, [0, 7])
        XCTAssertEqual(availabilityHashCaptor.value, bestBlockHash)
    }

    func testStakeInfoFailurePropagates() {
        let apiFactory = createApiFactory(stakeInfoResult: .createWithError(CommonError.dataCorruption))

        XCTAssertThrowsError(try fetchState(using: apiFactory))
    }

    private func stakeInfo(netuid: UInt16, stake: Balance) -> SubtensorPallet.StakeInfo {
        SubtensorPallet.StakeInfo(
            hotkey: hotkey,
            netuid: netuid,
            stake: stake,
            isRegistered: true
        )
    }

    private func position(netuid: UInt16, stake: Balance) -> SubtensorPosition {
        SubtensorPosition(
            hotkey: hotkey,
            netuid: netuid,
            stakeAlpha: stake,
            isRegistered: true
        )
    }

    private func createApiFactory(
        stakeInfoResult: CompoundOperationWrapper<[SubtensorPallet.StakeInfo]>,
        availabilities: [SubtensorPallet.ColdkeyStakeAvailability] = []
    ) -> MockSubtensorApiOperationFactoryProtocol {
        let apiFactory = MockSubtensorApiOperationFactoryProtocol()

        stub(apiFactory) { stub in
            when(stub.createBestBlockHashWrapper()).thenReturn(
                CompoundOperationWrapper.createWithResult(bestBlockHash)
            )
            when(stub.createStakeInfoWrapper(for: any(), blockHash: any())).thenReturn(stakeInfoResult)
            when(stub.createStakeAvailabilityWrapper(for: any(), netuids: any(), blockHash: any())).thenReturn(
                CompoundOperationWrapper.createWithResult(availabilities)
            )
            when(stub.createRootClaimPreviewsWrapper(coldkey: any(), blockHash: any())).thenReturn(
                CompoundOperationWrapper.createWithResult([])
            )
            when(stub.createRootClaimableThresholdWrapper(blockHash: any())).thenReturn(
                CompoundOperationWrapper.createWithResult(nil)
            )
        }

        return apiFactory
    }

    private func fetchState(
        using apiFactory: SubtensorApiOperationFactoryProtocol
    ) throws -> Multistaking.SubtensorState {
        let factory = SubtensorStakeStateFetchOperationFactory(operationFactory: apiFactory, operationQueue: OperationQueue())
        let wrapper = factory.createStateWrapper(for: coldkey)

        OperationQueue().addOperations(wrapper.allOperations, waitUntilFinished: true)

        return try wrapper.targetOperation.extractNoCancellableResultData()
    }
}
