import Foundation
import BigInt

final class SubtensorStakingPresenter: SubtensorStakingPresenterProtocol {
    weak var view: SubtensorStakingViewProtocol?
    let interactor: SubtensorStakingInteractorInputProtocol
    let wireframe: SubtensorStakingWireframeProtocol

    private let chainAsset: ChainAsset
    /// The netuid of the asset the user tapped on the multistaking dashboard
    /// (root = 0, SN# = subnet id). The dashboard is scoped to this netuid:
    /// the "Your stake" total and the "Your validator(s)" card only show
    /// data for this netuid, so tapping the SN8 card lands on an SN8-only
    /// view.
    private let entryNetuid: UInt16
    private var scopedPositions: [SubtensorStakePosition] = []

    init(
        interactor: SubtensorStakingInteractorInputProtocol,
        wireframe: SubtensorStakingWireframeProtocol,
        chainAsset: ChainAsset,
        entryNetuid: UInt16
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.chainAsset = chainAsset
        self.entryNetuid = entryNetuid
    }

    func setup() {
        interactor.setup()
    }

    func refresh() {
        // Skip the loading state here — the screen already has stale data
        // rendered, and showing a spinner in place of it on every navigation
        // would feel jumpy. New data lands silently when the fetch returns.
        interactor.refresh()
    }

    func didTapStakeMore() {
        guard let controller = view?.controller else { return }
        wireframe.showStakingFlow(from: controller)
    }

    func didTapUnstake() {
        guard let controller = view?.controller else { return }
        guard !scopedPositions.isEmpty else { return }
        wireframe.showUnstake(from: controller, positions: scopedPositions)
    }
}

extension SubtensorStakingPresenter: SubtensorStakingInteractorOutputProtocol {
    func didReceive(positions: [SubtensorStakePosition]) {
        let precision = chainAsset.assetDisplayInfo.assetPrecision

        // Scope to the entry netuid — the dashboard only ever renders one
        // type of stake at a time (root TAO or one subnet's alpha), even
        // though the underlying position cache holds every netuid.
        scopedPositions = positions.filter { $0.netuid == entryNetuid }

        let total: BigUInt = scopedPositions.reduce(BigUInt(0)) { $0 + $1.amount }

        let totalRow: SubtensorStakeAmountsView.Row?
        if total > 0 {
            let amount = SubtensorPositionViewModel.formatAmount(
                total,
                precision: max(0, Int(precision)),
                isRoot: entryNetuid == SubtensorStakingConstants.rootNetuid
            )
            let badge = entryNetuid == SubtensorStakingConstants.rootNetuid
                ? nil
                : "SN\(entryNetuid)"
            totalRow = SubtensorStakeAmountsView.Row(amountText: amount, netuidBadge: badge)
        } else {
            totalRow = nil
        }

        let validatorViewModels = scopedPositions.map {
            SubtensorPositionViewModel.make(from: $0, assetPrecision: precision)
        }

        let validatorsTitle = validatorViewModels.count == 1
            ? "Your validator"
            : "Your validators"

        let viewModel = SubtensorStakingDashboardViewModel(
            totalStakeRow: totalRow,
            validatorsTitle: validatorsTitle,
            validatorRows: validatorViewModels,
            info: Self.makeStaticInfo()
        )

        view?.didReceive(viewModel: viewModel)
    }

    func didReceive(error: Error) {
        Logger.shared.error("SubtensorStaking: \(error.localizedDescription)")
        guard let view else { return }
        wireframe.showError(from: view.controller, message: error.localizedDescription)
    }
}

// MARK: - Static info

private extension SubtensorStakingPresenter {
    /// Static "Staking info" footer values. Verified against finney mainnet
    /// 2026-04-30. Reward time + max APR were intentionally dropped — both
    /// vary per validator/subnet and would mislead more than inform here;
    /// the start-staking info screen surfaces them in the right context.
    static func makeStaticInfo() -> SubtensorStakingInfoView.Model {
        SubtensorStakingInfoView.Model(
            minStake: "0.01 TAO",
            unstakingPeriod: "Instant"
        )
    }
}
