import Foundation

final class ParaStkStakeSetupWireframe: ParaStkStakeSetupWireframeProtocol {
    let state: ParachainStakingSharedState

    init(state: ParachainStakingSharedState) {
        self.state = state
    }

    func showConfirmation(
        from view: ParaStkStakeSetupViewProtocol?,
        collator: DisplayAddress,
        amount: Decimal
    ) {
        guard let confirmView = ParaStkStakeConfirmViewFactory.createView(
            for: state,
            collator: collator,
            amount: amount
        ) else {
            return
        }

        view?.controller.navigationController?.pushViewController(
            confirmView.controller,
            animated: true
        )
    }

    func showCollatorSelection(from view: ParaStkStakeSetupViewProtocol?) {
        guard let collatorsView = ParaStkSelectCollatorsViewFactory.createView(with: state) else {
            return
        }

        view?.controller.navigationController?.pushViewController(collatorsView.controller, animated: true)
    }
}
