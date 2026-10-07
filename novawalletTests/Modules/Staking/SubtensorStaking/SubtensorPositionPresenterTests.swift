import Cuckoo
import Foundation_iOS
@testable import novawallet
import XCTest

final class SubtensorPositionPresenterTests: XCTestCase {
    func testRewardsShowTheDashWhenTheClaimPreviewFails() {
        let view = MockSubtensorPositionViewProtocol()
        let viewModels = capture(view)
        let presenter = makePresenter(group: makeRootGroup(isRegistered: true), view: view)

        presenter.didReceiveClaimableFailure(true)

        XCTAssertEqual(viewModels.last?.summary.rows.map(\.title), ["Rewards"])
        XCTAssertEqual(viewModels.last?.summary.rows.first?.value, .loaded(value: "—", detail: nil, isPositive: false))
    }

    func testRewardsCountTheClaimPreviewOfAHotkeyThatLeftRoot() {
        let view = MockSubtensorPositionViewProtocol()
        let viewModels = capture(view)
        let presenter = makePresenter(group: makeRootGroup(isRegistered: true), view: view)

        presenter.didReceive(claimable: SubtensorRootClaimable(previews: [
            SubtensorRootClaimPreview(
                hotkey: Data(repeating: 7, count: 32),
                accrued: 300_000_000,
                redeemable: 300_000_000,
                forfeitedEstimate: 0
            ),
            SubtensorRootClaimPreview(
                hotkey: Data(repeating: 9, count: 32),
                accrued: 120_000_000,
                redeemable: 120_000_000,
                forfeitedEstimate: 0
            )
        ]))

        XCTAssertEqual(
            viewModels.last?.summary.rows.first?.value,
            .loaded(value: "0.42 TAO", detail: nil, isPositive: false)
        )
    }

    func testPrimaryValidatorWithoutAUidShowsTheInactivePill() {
        let view = MockSubtensorPositionViewProtocol()
        let viewModels = capture(view)
        let presenter = makePresenter(group: makeRootGroup(isRegistered: false), view: view)

        presenter.setup()

        XCTAssertEqual(viewModels.last?.summary.isActive, false)
    }

    func testRegisteredPrimaryValidatorShowsTheActivePill() {
        let view = MockSubtensorPositionViewProtocol()
        let viewModels = capture(view)
        let presenter = makePresenter(group: makeRootGroup(isRegistered: true), view: view)

        presenter.setup()

        XCTAssertEqual(viewModels.last?.summary.isActive, true)
    }

    func testRootPositionOffersTheClaimEntryFirst() {
        let view = MockSubtensorPositionViewProtocol()
        let viewModels = capture(view)
        let presenter = makePresenter(group: makeRootGroup(isRegistered: true), view: view)

        presenter.didReceive(claimable: SubtensorRootClaimable(previews: [
            SubtensorRootClaimPreview(
                hotkey: Data(repeating: 7, count: 32),
                accrued: 420_000_000,
                redeemable: 420_000_000,
                forfeitedEstimate: 0
            )
        ]))

        XCTAssertEqual(viewModels.last?.actions.map(\.action), [.claim, .addStake, .unstake])
        XCTAssertEqual(viewModels.last?.actions.map(\.title), ["Claim rewards", "Add stake", "Unstake"])
    }

    func testCachedCatalogueOpensTheSubnetPositionWithoutTheSummarySkeleton() {
        let view = MockSubtensorPositionViewProtocol()
        let viewModels = capture(view)
        let group = makeSubnetGroup()
        let presenter = makePresenter(
            group: group,
            view: view,
            snapshot: SubtensorPositionSnapshot(
                catalogue: .fresh(makeCatalogue(netuid: group.netuid), freshUntil: 300),
                rootRate: .miss,
                yields: .miss
            )
        )

        presenter.setup()

        XCTAssertNotNil(viewModels.last?.summary.caption)
        XCTAssertNotNil(viewModels.last?.summary.amount)
    }

    private final class CapturedViewModels {
        var last: SubtensorPositionViewModel?
    }

    private func capture(_ view: MockSubtensorPositionViewProtocol) -> CapturedViewModels {
        let viewModels = CapturedViewModels()

        stub(view) { stub in
            when(stub.didReceive(viewModel: any())).then { viewModels.last = $0 }
        }

        return viewModels
    }

    private func makePresenter(
        group: SubtensorPortfolioGroup,
        view: MockSubtensorPositionViewProtocol,
        snapshot: SubtensorPositionSnapshot = SubtensorPositionSnapshot(catalogue: .miss, rootRate: .miss, yields: .miss)
    ) -> SubtensorPositionPresenter {
        let interactor = MockSubtensorPositionInteractorInputProtocol()

        stub(interactor) { stub in
            when(stub.cachedSnapshot()).thenReturn(snapshot)
            when(stub.setup()).thenDoNothing()
            when(stub.loadValidator(any(), on: any())).thenDoNothing()
            when(stub.loadRootHolds(for: any())).thenDoNothing()
            when(stub.loadHistory(for: any(), period: any())).thenDoNothing()
        }

        let presenter = SubtensorPositionPresenter(
            group: group,
            account: SubtensorFlowChainWorld.coldkeyAccount(),
            chainAsset: SubtensorFlowChainWorld.chainAsset(),
            pendingRootClaims: SubtensorPendingRootClaims(),
            interactor: interactor,
            wireframe: MockSubtensorPositionWireframeProtocol(),
            viewModelFactory: SubtensorPositionViewModelFactory(
                chainAsset: SubtensorFlowChainWorld.chainAsset(),
                priceAssetInfoFactory: PriceAssetInfoFactory(currencyManager: CurrencyManagerStub())
            ),
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view

        return presenter
    }

    private func makeRootGroup(isRegistered: Bool) -> SubtensorPortfolioGroup {
        let hotkey = Data(repeating: 7, count: 32)

        return SubtensorPortfolioGroup(
            netuid: SubtensorStakingPallet.rootNetuid,
            positions: [
                SubtensorStakingPosition(
                    hotkey: hotkey,
                    netuid: SubtensorStakingPallet.rootNetuid,
                    stakeAlpha: 20_000_000_000,
                    hotkeyEmissionPerTempo: 0,
                    totalHotkeyAlpha: nil,
                    isRegistered: isRegistered
                )
            ],
            totalAlpha: 20_000_000_000,
            redeemable: 0,
            taoValue: 20_000_000_000,
            availability: nil,
            primaryHotkey: hotkey
        )
    }

    private func makeSubnetGroup() -> SubtensorPortfolioGroup {
        let hotkey = Data(repeating: 7, count: 32)

        return SubtensorPortfolioGroup(
            netuid: 64,
            positions: [
                SubtensorStakingPosition(
                    hotkey: hotkey,
                    netuid: 64,
                    stakeAlpha: 20_000_000_000,
                    hotkeyEmissionPerTempo: 0,
                    totalHotkeyAlpha: nil,
                    isRegistered: true
                )
            ],
            totalAlpha: 20_000_000_000,
            redeemable: 0,
            taoValue: 1_476_000_000,
            availability: nil,
            primaryHotkey: hotkey
        )
    }

    private func makeCatalogue(netuid: UInt16) -> SubtensorSubnetCatalogue {
        let stamp = SubtensorBackendStamp(asOf: Date(timeIntervalSince1970: 1_790_000_000), freshness: .fresh)

        return SubtensorSubnetCatalogue(subnets: [
            SubtensorCatalogueSubnet(
                netuid: netuid,
                name: "Chutes",
                symbol: "ش",
                networkRegisteredAt: 4_531_295,
                tempo: 360,
                ownerColdkey: "",
                ownerHotkey: "",
                links: SubtensorSubnetLinks(
                    githubRepo: "",
                    subnetContact: "",
                    subnetUrl: "",
                    subnetWebsite: "",
                    discord: "",
                    additional: ""
                ),
                taoReserve: 210_000_000_000_000,
                alphaReserve: 2_845_000_000_000_000,
                alphaOutstanding: 3_100_000_000_000_000,
                taoPerAlpha: 73_800_000,
                metadataStamp: stamp,
                pricesStamp: stamp
            )
        ])
    }
}
