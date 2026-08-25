import BigInt
import Foundation_iOS
@testable import novawallet
import SubstrateSdk
import XCTest

final class SubtensorStkStateViewModelFactoryTests: XCTestCase {
    private let enLocale = Locale(identifier: "en")
    private let rootHotkey = Data(repeating: 0x11, count: 32)
    private let subnetHotkey = Data(repeating: 0x22, count: 32)

    private func makeFactory() -> SubtensorStkStateViewModelFactory {
        SubtensorStkStateViewModelFactory(
            priceAssetInfoFactory: PriceAssetInfoFactory(currencyManager: CurrencyManagerStub())
        )
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
            enabled: true,
            source: .remote
        )

        let chain = ChainModelGenerator.generateChain(
            assets: [asset],
            defaultChainId: KnowChainId.bittensor,
            addressPrefix: 42
        )

        return ChainAsset(chain: chain, asset: asset)
    }

    private func makePosition(
        hotkey: Data,
        netuid: UInt16,
        stake: BigUInt,
        registered: Bool = true
    ) -> SubtensorStakingPosition {
        SubtensorStakingPosition(
            hotkey: hotkey,
            netuid: netuid,
            stakeAlpha: stake,
            hotkeyEmissionPerTempo: 0,
            isRegistered: registered
        )
    }

    private func makeDynamicInfo(netuid: UInt16, symbol: String) -> SubtensorStakingPallet.DynamicInfo {
        SubtensorStakingPallet.DynamicInfo(
            netuid: netuid,
            ownerHotkey: Data(repeating: 0, count: 32),
            ownerColdkey: Data(repeating: 0, count: 32),
            subnetName: Data("subnet".utf8),
            tokenSymbol: Data(symbol.utf8),
            tempo: 360,
            lastStep: 0,
            blocksSinceLastStep: 0,
            emission: 0,
            alphaIn: 0,
            alphaOut: 0,
            taoIn: 0,
            alphaOutEmission: 0,
            alphaInEmission: 0,
            taoInEmission: 0,
            pendingAlphaEmission: 0,
            pendingRootEmission: 0,
            subnetVolume: 0,
            networkRegisteredAt: 0,
            subnetIdentity: nil,
            movingPrice: .null
        )
    }

    private func makeStakedState(
        positions: [SubtensorStakingPosition],
        prices: [UInt16: BigUInt] = [:],
        claimable: SubtensorRootClaimable? = nil,
        subnets: [SubtensorStakingPallet.DynamicInfo] = []
    ) -> SubtensorStakingStakedState {
        var commonData = SubtensorStakingCommonData
            .empty
            .byReplacing(chainAsset: makeChainAsset())
            .byReplacing(claimable: claimable)

        if !subnets.isEmpty {
            commonData = commonData.byReplacing(
                subnetsInfo: SubtensorSubnetsInfo(subnets: subnets, prices: [:])
            )
        }

        return SubtensorStakingStakedState(
            stateMachine: nil,
            commonData: commonData,
            stakingState: Multistaking.SubtensorStakingState(positions: positions, prices: prices)
        )
    }

    private func extractNominatorState(
        _ viewState: StakingViewState
    ) -> (
        viewModel: LocalizableResource<NominationViewModel>,
        alerts: [StakingAlert],
        reward: LocalizableResource<StakingRewardViewModel>?,
        unbondings: StakingUnbondingViewModel?,
        actions: [StakingManageOption]
    )? {
        guard case let .nominator(viewModel, alerts, reward, unbondings, actions) = viewState else {
            return nil
        }

        return (viewModel, alerts, reward, unbondings, actions)
    }

    func testInitStateProducesUndefinedViewModel() {
        let state = SubtensorStakingInitState(stateMachine: nil, commonData: .empty)

        let viewState = makeFactory().createViewModel(from: state)

        XCTAssertEqual(viewState.rawType, StakingViewState.undefined.rawType)
    }

    func testNotStakedStateProducesUndefinedViewModel() {
        let state = SubtensorStakingNotStakedState(stateMachine: nil, commonData: .empty)

        let viewState = makeFactory().createViewModel(from: state)

        XCTAssertEqual(viewState.rawType, StakingViewState.undefined.rawType)
    }

    func testStakedStateProducesNominatorViewModelWithoutUnbondings() {
        let state = makeStakedState(
            positions: [makePosition(hotkey: rootHotkey, netuid: 0, stake: 2_500_000_000)]
        )

        let viewState = makeFactory().createViewModel(from: state)

        let nominator = extractNominatorState(viewState)

        XCTAssertNotNil(nominator)
        XCTAssertNil(nominator?.unbondings)
    }

    func testStakedStateActionsIncludePositionsListWithCount() {
        let state = makeStakedState(
            positions: [
                makePosition(hotkey: rootHotkey, netuid: 0, stake: 2_500_000_000),
                makePosition(hotkey: subnetHotkey, netuid: 64, stake: 1_000_000_000)
            ],
            prices: [64: 1_000_000_000]
        )

        let actions = extractNominatorState(makeFactory().createViewModel(from: state))?.actions

        XCTAssertEqual(actions?.count, 3)

        guard
            case .stakeMore = actions?[0],
            case .unstake = actions?[1],
            case let .changeValidators(count) = actions?[2] else {
            return XCTFail("Unexpected actions: \(String(describing: actions))")
        }

        XCTAssertEqual(count, 2)
    }

    func testRootOnlyTotalIsExactFormattedAmount() {
        let state = makeStakedState(
            positions: [makePosition(hotkey: rootHotkey, netuid: 0, stake: 2_500_000_000)]
        )

        let nomination = extractNominatorState(
            makeFactory().createViewModel(from: state)
        )?.viewModel.value(for: enLocale)

        XCTAssertEqual(nomination?.totalStakedAmount, "2.5 TAO")
    }

    func testAlphaIncludedTotalIsMarkedApproximate() {
        let state = makeStakedState(
            positions: [
                makePosition(hotkey: rootHotkey, netuid: 0, stake: 2_000_000_000),
                makePosition(hotkey: subnetHotkey, netuid: 64, stake: 1_000_000_000)
            ],
            prices: [64: 500_000_000]
        )

        let nomination = extractNominatorState(
            makeFactory().createViewModel(from: state)
        )?.viewModel.value(for: enLocale)

        XCTAssertEqual(nomination?.totalStakedAmount, "~2.5 TAO")
    }

    func testStatusActiveWhenAnyPositionRegistered() {
        let state = makeStakedState(
            positions: [
                makePosition(hotkey: rootHotkey, netuid: 0, stake: 1_000_000_000, registered: true),
                makePosition(hotkey: subnetHotkey, netuid: 64, stake: 1_000_000_000, registered: false)
            ]
        )

        let nomination = extractNominatorState(
            makeFactory().createViewModel(from: state)
        )?.viewModel.value(for: enLocale)

        guard case .active = nomination?.status else {
            return XCTFail("Expected active status")
        }
    }

    func testStatusInactiveWhenNoPositionRegistered() {
        let state = makeStakedState(
            positions: [makePosition(hotkey: rootHotkey, netuid: 0, stake: 1_000_000_000, registered: false)]
        )

        let nomination = extractNominatorState(
            makeFactory().createViewModel(from: state)
        )?.viewModel.value(for: enLocale)

        guard case .inactive = nomination?.status else {
            return XCTFail("Expected inactive status")
        }
    }

    func testEligibleClaimableEnablesClaimAction() {
        let state = makeStakedState(
            positions: [makePosition(hotkey: rootHotkey, netuid: 0, stake: 1_000_000_000)],
            claimable: SubtensorRootClaimable(
                owed: 700_000,
                positions: [
                    SubtensorStakingPallet.RootBasketPosition(
                        hotkey: rootHotkey,
                        owedShares: 10,
                        payout: 700_000
                    )
                ]
            )
        )

        let reward = extractNominatorState(
            makeFactory().createViewModel(from: state)
        )?.reward?.value(for: enLocale)

        guard case let .loaded(claimable) = reward?.claimableRewards else {
            return XCTFail("Expected loaded claimable")
        }

        XCTAssertTrue(claimable.canClaim)
        XCTAssertEqual(claimable.balance.amount, "0.0007 TAO")
    }

    func testSubThresholdClaimableShowsEligibleOnlyAndDisablesClaimAction() {
        let state = makeStakedState(
            positions: [makePosition(hotkey: rootHotkey, netuid: 0, stake: 1_000_000_000)],
            claimable: SubtensorRootClaimable(
                owed: 400_000,
                positions: [
                    SubtensorStakingPallet.RootBasketPosition(
                        hotkey: rootHotkey,
                        owedShares: 10,
                        payout: 400_000
                    )
                ]
            )
        )

        let reward = extractNominatorState(
            makeFactory().createViewModel(from: state)
        )?.reward?.value(for: enLocale)

        guard case let .loaded(claimable) = reward?.claimableRewards else {
            return XCTFail("Expected loaded claimable")
        }

        XCTAssertFalse(claimable.canClaim)
        XCTAssertEqual(claimable.balance.amount, "0 TAO")
    }

    func testMixedClaimableShowsEligibleTotalOnly() {
        let state = makeStakedState(
            positions: [makePosition(hotkey: rootHotkey, netuid: 0, stake: 1_000_000_000)],
            claimable: SubtensorRootClaimable(
                owed: 1_100_000,
                positions: [
                    SubtensorStakingPallet.RootBasketPosition(
                        hotkey: rootHotkey,
                        owedShares: 10,
                        payout: 700_000
                    ),
                    SubtensorStakingPallet.RootBasketPosition(
                        hotkey: subnetHotkey,
                        owedShares: 10,
                        payout: 400_000
                    )
                ]
            )
        )

        let reward = extractNominatorState(
            makeFactory().createViewModel(from: state)
        )?.reward?.value(for: enLocale)

        guard case let .loaded(claimable) = reward?.claimableRewards else {
            return XCTFail("Expected loaded claimable")
        }

        XCTAssertTrue(claimable.canClaim)
        XCTAssertEqual(claimable.balance.amount, "0.0007 TAO")
    }

    func testZeroClaimableDisablesClaimAction() {
        let state = makeStakedState(
            positions: [makePosition(hotkey: rootHotkey, netuid: 0, stake: 1_000_000_000)],
            claimable: SubtensorRootClaimable(owed: 0, positions: [])
        )

        let reward = extractNominatorState(
            makeFactory().createViewModel(from: state)
        )?.reward?.value(for: enLocale)

        guard case let .loaded(claimable) = reward?.claimableRewards else {
            return XCTFail("Expected loaded claimable")
        }

        XCTAssertFalse(claimable.canClaim)
    }

    func testUnregisteredPositionProducesAlert() {
        let state = makeStakedState(
            positions: [makePosition(hotkey: rootHotkey, netuid: 0, stake: 1_000_000_000, registered: false)]
        )

        let alerts = extractNominatorState(makeFactory().createViewModel(from: state))?.alerts

        XCTAssertEqual(alerts?.count, 1)

        guard case .nominatorChangeValidators = alerts?.first else {
            return XCTFail("Expected change validators alert")
        }
    }

    func testRegisteredPositionsProduceNoAlerts() {
        let state = makeStakedState(
            positions: [makePosition(hotkey: rootHotkey, netuid: 0, stake: 1_000_000_000)]
        )

        let alerts = extractNominatorState(makeFactory().createViewModel(from: state))?.alerts

        XCTAssertEqual(alerts?.isEmpty, true)
    }

    func testPositionViewModelsSortRootFirstAndAreReadOnly() {
        let state = makeStakedState(
            positions: [
                makePosition(hotkey: subnetHotkey, netuid: 64, stake: 9_000_000_000),
                makePosition(hotkey: rootHotkey, netuid: 0, stake: 1_500_000_000)
            ],
            subnets: [makeDynamicInfo(netuid: 64, symbol: "α")]
        )

        let viewModels = makeFactory().createPositionViewModels(
            for: state.stakingState,
            commonData: state.commonData
        ).map { $0.value(for: enLocale) }

        XCTAssertEqual(viewModels.count, 2)
        XCTAssertEqual(viewModels[0].underlyingViewModel.details?.subtitle, "1.5 TAO")
        XCTAssertEqual(viewModels[1].underlyingViewModel.details?.subtitle, "9 α")
        XCTAssertTrue(viewModels.allSatisfy { !$0.selectable })
    }

    func testPositionViewModelFallsBackToNetuidWhenSymbolUnknown() {
        let state = makeStakedState(
            positions: [makePosition(hotkey: subnetHotkey, netuid: 77, stake: 2_000_000_000)]
        )

        let viewModels = makeFactory().createPositionViewModels(
            for: state.stakingState,
            commonData: state.commonData
        ).map { $0.value(for: enLocale) }

        XCTAssertEqual(viewModels.first?.underlyingViewModel.details?.subtitle, "2 SN77")
    }

    func testNetworkInfoViewModelExposesMinStakeOnly() {
        let viewModel = makeFactory().createNetworkInfoViewModel(
            from: SubtensorNetworkInfo(
                minStake: 500_000,
                effectiveNominatorMinStake: 5_000_000,
                rootUnlockInterval: 0,
                rootClaimableThreshold: 500_000
            ),
            chainAsset: makeChainAsset(),
            price: nil,
            locale: enLocale
        )

        XCTAssertEqual(viewModel.minimalStake?.value?.amount, "0.0005 TAO")
        XCTAssertNil(viewModel.totalStake)
        XCTAssertNil(viewModel.activeNominators)
        XCTAssertNil(viewModel.stakingPeriod)
        XCTAssertNil(viewModel.lockUpPeriod)
    }
}
