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

    func testRootPositionOffersNoClaimEntry() {
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

        XCTAssertEqual(viewModels.last?.actions.map(\.action), [.addStake, .unstake])
        XCTAssertEqual(viewModels.last?.actions.map(\.title), ["Add stake", "Unstake"])
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
        view: MockSubtensorPositionViewProtocol
    ) -> SubtensorPositionPresenter {
        let interactor = MockSubtensorPositionInteractorInputProtocol()

        stub(interactor) { stub in
            when(stub.cachedSnapshot()).thenReturn(
                SubtensorPositionSnapshot(catalogue: .miss, rootRate: .miss, yields: .miss)
            )
            when(stub.setup()).thenDoNothing()
            when(stub.loadValidator(any(), on: any())).thenDoNothing()
            when(stub.loadRootHolds(for: any())).thenDoNothing()
        }

        let presenter = SubtensorPositionPresenter(
            group: group,
            account: SubtensorFlowChainWorld.coldkeyAccount(),
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
            taoValue: 20_000_000_000,
            availability: nil,
            primaryHotkey: hotkey
        )
    }
}
