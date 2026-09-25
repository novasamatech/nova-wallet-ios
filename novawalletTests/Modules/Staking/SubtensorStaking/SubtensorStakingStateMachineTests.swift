import BigInt
@testable import novawallet
import XCTest

final class SubtensorStakingStateMachineTests: XCTestCase {
    private func makePosition(
        netuid: UInt16 = 0,
        stake: BigUInt = 1_000_000_000,
        registered: Bool = true
    ) -> SubtensorStakingPosition {
        SubtensorStakingPosition(
            hotkey: Data(repeating: 0x11, count: 32),
            netuid: netuid,
            stakeAlpha: stake,
            hotkeyEmissionPerTempo: 0,
            totalHotkeyAlpha: nil,
            isRegistered: registered
        )
    }

    private func makeStakingState(
        positions: [SubtensorStakingPosition]
    ) -> Multistaking.SubtensorStakingState {
        Multistaking.SubtensorStakingState(positions: positions, prices: [:])
    }

    private func makeChainAsset() -> ChainAsset {
        let asset = AssetModel(
            assetId: AssetModel.utilityAssetId,
            icon: nil,
            name: "Bittensor",
            symbol: "TAO",
            precision: 9,
            priceId: nil,
            stakings: [.subtensor],
            type: nil,
            typeExtras: nil,
            buyProviders: nil,
            sellProviders: nil,
            source: .remote
        )

        let chain = ChainModelGenerator.generateChain(
            assets: [asset],
            defaultChainId: KnowChainId.bittensor,
            addressPrefix: 42
        )

        return ChainAsset(chain: chain, asset: asset)
    }

    func testInitialStateIsInit() {
        let machine = SubtensorStakingStateMachine()

        XCTAssertTrue(machine.state is SubtensorStakingInitState)
    }

    func testUndefinedPositionsKeepInitState() {
        let machine = SubtensorStakingStateMachine()

        machine.state.process(positionsState: nil)

        XCTAssertTrue(machine.state is SubtensorStakingInitState)
    }

    func testEmptyPositionsMoveToNotStaked() {
        let machine = SubtensorStakingStateMachine()

        machine.state.process(positionsState: makeStakingState(positions: []))

        XCTAssertTrue(machine.state is SubtensorStakingNotStakedState)
    }

    func testActivePositionsMoveToStaked() {
        let machine = SubtensorStakingStateMachine()

        machine.state.process(positionsState: makeStakingState(positions: [makePosition()]))

        let stakedState = machine.state as? SubtensorStakingStakedState

        XCTAssertEqual(stakedState?.stakingState.positions, [makePosition()])
    }

    func testStakedUpdatesInPlaceOnNewPositions() {
        let machine = SubtensorStakingStateMachine()

        machine.state.process(positionsState: makeStakingState(positions: [makePosition()]))

        let stakedState = machine.state as? SubtensorStakingStakedState

        let newPositions = [makePosition(stake: 5_000_000_000), makePosition(netuid: 64)]
        machine.state.process(positionsState: makeStakingState(positions: newPositions))

        XCTAssertTrue((machine.state as? SubtensorStakingStakedState) === stakedState)
        XCTAssertEqual(stakedState?.stakingState.positions, newPositions)
    }

    func testStakedFallsBackToNotStakedWhenPositionsEmpty() {
        let machine = SubtensorStakingStateMachine()

        machine.state.process(positionsState: makeStakingState(positions: [makePosition()]))
        machine.state.process(positionsState: makeStakingState(positions: []))

        XCTAssertTrue(machine.state is SubtensorStakingNotStakedState)
    }

    func testStakedFallsBackToInitWhenPositionsUndefined() {
        let machine = SubtensorStakingStateMachine()

        machine.state.process(positionsState: makeStakingState(positions: [makePosition()]))
        machine.state.process(positionsState: nil)

        XCTAssertTrue(machine.state is SubtensorStakingInitState)
    }

    func testChainAssetChangeResetsToInit() {
        let machine = SubtensorStakingStateMachine()

        machine.state.process(chainAsset: makeChainAsset())
        machine.state.process(positionsState: makeStakingState(positions: [makePosition()]))

        let otherChainAsset = ChainAsset(
            chain: ChainModelGenerator.generateChain(generatingAssets: 1, addressPrefix: 0),
            asset: makeChainAsset().asset
        )

        machine.state.process(chainAsset: otherChainAsset)

        XCTAssertTrue(machine.state is SubtensorStakingInitState)
    }

    func testCommonDataUpdateKeepsStakedState() {
        let machine = SubtensorStakingStateMachine()

        machine.state.process(positionsState: makeStakingState(positions: [makePosition()]))

        let claimable = SubtensorRootClaimable(
            previews: [
                SubtensorRootClaimPreview(
                    hotkey: Data(repeating: 3, count: 32),
                    accrued: 42,
                    redeemable: 42,
                    forfeitedEstimate: 0
                )
            ]
        )
        machine.state.process(claimable: claimable)

        let stakedState = machine.state as? SubtensorStakingStakedState

        XCTAssertEqual(stakedState?.commonData.claimable, claimable)
    }

    func testAccountUpdateResetsToInit() {
        let machine = SubtensorStakingStateMachine()

        machine.state.process(positionsState: makeStakingState(positions: [makePosition()]))
        machine.state.process(account: nil)

        XCTAssertTrue(machine.state is SubtensorStakingInitState)
    }

    func testSyncFailureIsCarriedIntoCommonDataWithoutLeavingStakedState() {
        let machine = SubtensorStakingStateMachine()

        machine.state.process(positionsState: makeStakingState(positions: [makePosition()]))
        machine.state.process(positionsSyncFailed: true)

        let stakedState = machine.state as? SubtensorStakingStakedState

        XCTAssertEqual(stakedState?.commonData.positionsSyncFailed, true)
    }

    func testRecoveredSyncClearsTheFailureFlag() {
        let machine = SubtensorStakingStateMachine()

        machine.state.process(positionsState: makeStakingState(positions: [makePosition()]))
        machine.state.process(positionsSyncFailed: true)
        machine.state.process(positionsSyncFailed: false)

        let stakedState = machine.state as? SubtensorStakingStakedState

        XCTAssertEqual(stakedState?.commonData.positionsSyncFailed, false)
    }

    func testSafeModeFlagIsCarriedIntoCommonData() {
        let machine = SubtensorStakingStateMachine()

        machine.state.process(positionsState: makeStakingState(positions: [makePosition()]))
        machine.state.process(
            networkInfo: SubtensorNetworkInfo(
                minStake: 500_000,
                effectiveNominatorMinStake: 5_000_000,
                rootUnlockInterval: 0,
                rootClaimableThreshold: 500_000,
                isSafeModeActive: true
            )
        )

        let stakedState = machine.state as? SubtensorStakingStakedState

        XCTAssertEqual(stakedState?.commonData.networkInfo?.isSafeModeActive, true)
    }
}
