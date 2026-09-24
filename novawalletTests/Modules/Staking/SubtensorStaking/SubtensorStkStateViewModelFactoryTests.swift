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
        registered: Bool = true,
        emission: BigUInt = 0,
        totalHotkeyAlpha: BigUInt? = nil
    ) -> SubtensorStakingPosition {
        SubtensorStakingPosition(
            hotkey: hotkey,
            netuid: netuid,
            stakeAlpha: stake,
            hotkeyEmissionPerTempo: emission,
            totalHotkeyAlpha: totalHotkeyAlpha,
            isRegistered: registered
        )
    }

    private func makeNetworkInfo(isSafeModeActive: Bool = false) -> SubtensorNetworkInfo {
        SubtensorNetworkInfo(
            minStake: 500_000,
            effectiveNominatorMinStake: 5_000_000,
            rootUnlockInterval: 0,
            rootClaimableThreshold: 500_000,
            isSafeModeActive: isSafeModeActive
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
        subnets: [SubtensorStakingPallet.DynamicInfo] = [],
        networkInfo: SubtensorNetworkInfo? = nil,
        positionsSyncFailed: Bool = false
    ) -> SubtensorStakingStakedState {
        var commonData = SubtensorStakingCommonData
            .empty
            .byReplacing(chainAsset: makeChainAsset())
            .byReplacing(claimable: claimable)
            .byReplacing(networkInfo: networkInfo)
            .byReplacing(positionsSyncFailed: positionsSyncFailed)

        if !subnets.isEmpty {
            commonData = commonData.byReplacing(
                subnetsInfo: SubtensorSubnetsInfo(
                    subnets: subnets,
                    prices: [:],
                    subtokenEnabled: [],
                    ownerCut: SubtensorStakingPallet.defaultSubnetOwnerCut
                )
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
            commonData: state.commonData,
            selectable: false
        ).map { $0.value(for: enLocale) }

        XCTAssertEqual(viewModels.count, 2)
        XCTAssertEqual(viewModels[0].underlyingViewModel.details?.subtitle, "1.5 TAO")
        XCTAssertEqual(viewModels[1].underlyingViewModel.details?.subtitle, "9 α")
        XCTAssertTrue(viewModels.allSatisfy { !$0.selectable })
    }

    func testPositionViewModelsBecomeSelectableForUnstakeEntry() {
        let state = makeStakedState(
            positions: [
                makePosition(hotkey: subnetHotkey, netuid: 64, stake: 9_000_000_000),
                makePosition(hotkey: rootHotkey, netuid: 0, stake: 1_500_000_000)
            ],
            subnets: [makeDynamicInfo(netuid: 64, symbol: "α")]
        )

        let viewModels = makeFactory().createPositionViewModels(
            for: state.stakingState,
            commonData: state.commonData,
            selectable: true
        ).map { $0.value(for: enLocale) }

        XCTAssertTrue(viewModels.allSatisfy(\.selectable))
    }

    func testPositionViewModelFallsBackToNetuidWhenSymbolUnknown() {
        let state = makeStakedState(
            positions: [makePosition(hotkey: subnetHotkey, netuid: 77, stake: 2_000_000_000)]
        )

        let viewModels = makeFactory().createPositionViewModels(
            for: state.stakingState,
            commonData: state.commonData,
            selectable: false
        ).map { $0.value(for: enLocale) }

        XCTAssertEqual(viewModels.first?.underlyingViewModel.details?.subtitle, "2 SN77")
    }

    func testSafeModeProducesChainMaintenanceAlert() {
        let state = makeStakedState(
            positions: [makePosition(hotkey: rootHotkey, netuid: 0, stake: 1_000_000_000)],
            networkInfo: makeNetworkInfo(isSafeModeActive: true)
        )

        let alerts = extractNominatorState(makeFactory().createViewModel(from: state))?.alerts

        XCTAssertEqual(alerts?.count, 1)

        guard case let .chainMaintenance(title, _) = alerts?.first else {
            return XCTFail("Expected chain maintenance alert")
        }

        XCTAssertEqual(title.value(for: enLocale), "Network in safe mode")
    }

    func testInactiveSafeModeProducesNoChainMaintenanceAlert() {
        let state = makeStakedState(
            positions: [makePosition(hotkey: rootHotkey, netuid: 0, stake: 1_000_000_000)],
            networkInfo: makeNetworkInfo(isSafeModeActive: false)
        )

        let alerts = extractNominatorState(makeFactory().createViewModel(from: state))?.alerts

        XCTAssertEqual(alerts?.isEmpty, true)
    }

    func testFailedPositionsSyncProducesStaleDataAlert() {
        let state = makeStakedState(
            positions: [makePosition(hotkey: rootHotkey, netuid: 0, stake: 1_000_000_000)],
            positionsSyncFailed: true
        )

        let alerts = extractNominatorState(makeFactory().createViewModel(from: state))?.alerts

        XCTAssertEqual(alerts?.count, 1)

        guard case let .chainMaintenance(title, _) = alerts?.first else {
            return XCTFail("Expected chain maintenance alert")
        }

        XCTAssertEqual(title.value(for: enLocale), "Staking data may be out of date")
    }

    func testEligibleClaimableAboveThresholdProducesClaimAlert() {
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

        let alerts = extractNominatorState(makeFactory().createViewModel(from: state))?.alerts

        XCTAssertEqual(alerts?.count, 1)

        guard case let .claimRewards(_, details) = alerts?.first else {
            return XCTFail("Expected claim rewards alert")
        }

        XCTAssertEqual(
            details.value(for: enLocale),
            "You have 0.0007 TAO ready to claim on the Root Network."
        )
    }

    func testClaimableBelowThresholdProducesNoClaimAlert() {
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

        let alerts = extractNominatorState(makeFactory().createViewModel(from: state))?.alerts

        XCTAssertEqual(alerts?.isEmpty, true)
    }

    func testAlphaPositionRowShowsDailyRateAlongsideStakedAmount() {
        let state = makeStakedState(
            positions: [
                makePosition(
                    hotkey: subnetHotkey,
                    netuid: 64,
                    stake: 10_000_000_000_000,
                    emission: 26_188_601_273,
                    totalHotkeyAlpha: 573_318_341_062_634
                )
            ],
            subnets: [makeDynamicInfo(netuid: 64, symbol: "α")]
        )

        let viewModels = makeFactory().createPositionViewModels(
            for: state.stakingState,
            commonData: state.commonData,
            selectable: false
        ).map { $0.value(for: enLocale) }

        XCTAssertEqual(
            viewModels.first?.underlyingViewModel.details?.subtitle,
            "10,000 α · ≈ 9.13579 α/day"
        )
    }

    func testAlphaPositionRowOmitsRateUntilHotkeyAlphaArrives() {
        let state = makeStakedState(
            positions: [
                makePosition(
                    hotkey: subnetHotkey,
                    netuid: 64,
                    stake: 10_000_000_000_000,
                    emission: 26_188_601_273
                )
            ],
            subnets: [makeDynamicInfo(netuid: 64, symbol: "α")]
        )

        let viewModels = makeFactory().createPositionViewModels(
            for: state.stakingState,
            commonData: state.commonData,
            selectable: false
        ).map { $0.value(for: enLocale) }

        XCTAssertEqual(viewModels.first?.underlyingViewModel.details?.subtitle, "10,000 α")
    }

    func testRootPositionRowNeverShowsDailyRate() {
        let state = makeStakedState(
            positions: [
                makePosition(
                    hotkey: rootHotkey,
                    netuid: 0,
                    stake: 10_000_000_000_000,
                    emission: 26_188_601_273,
                    totalHotkeyAlpha: 573_318_341_062_634
                )
            ]
        )

        let viewModels = makeFactory().createPositionViewModels(
            for: state.stakingState,
            commonData: state.commonData,
            selectable: false
        ).map { $0.value(for: enLocale) }

        XCTAssertEqual(viewModels.first?.underlyingViewModel.details?.subtitle, "10,000 TAO")
    }

    func testAlphaPositionsRequestTheCompoundingNote() {
        let state = makeStakedState(
            positions: [
                makePosition(hotkey: rootHotkey, netuid: 0, stake: 1_000_000_000),
                makePosition(hotkey: subnetHotkey, netuid: 64, stake: 1_000_000_000)
            ],
            prices: [64: 1_000_000_000]
        )

        XCTAssertTrue(makeFactory().hasAlphaPositions(in: state.stakingState))
    }

    func testRootOnlyPositionsRequestNoCompoundingNote() {
        let state = makeStakedState(
            positions: [makePosition(hotkey: rootHotkey, netuid: 0, stake: 1_000_000_000)]
        )

        XCTAssertFalse(makeFactory().hasAlphaPositions(in: state.stakingState))
    }

    func testNetworkInfoViewModelExposesMinStakeOnly() {
        let viewModel = makeFactory().createNetworkInfoViewModel(
            from: makeNetworkInfo(),
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
