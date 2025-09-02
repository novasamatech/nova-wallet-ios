import Foundation
import Foundation_iOS

final class ParaStkStakeSetupWireframe: ParaStkStakeSetupWireframeProtocol {
    let state: ParachainStakingSharedStateProtocol

    init(state: ParachainStakingSharedStateProtocol) {
        self.state = state
    }

    func showConfirmation(
        from view: CollatorStakingSetupViewProtocol?,
        collator: DisplayAddress,
        amount: Decimal,
        initialDelegator: ParachainStaking.Delegator?
    ) {
        guard let confirmView = ParaStkStakeConfirmViewFactory.createView(
            for: state,
            collator: collator,
            amount: amount,
            initialDelegator: initialDelegator
        ) else {
            return
        }

        view?.controller.navigationController?.pushViewController(
            confirmView.controller,
            animated: true
        )
    }

    func showCollatorSelection(
        from view: CollatorStakingSetupViewProtocol?,
        delegate: CollatorStakingSelectDelegate
    ) {
        guard let collatorsView = CollatorStakingSelectViewFactory.createParachainStakingView(
            with: state,
            delegate: delegate
        ) else {
            return
        }

        view?.controller.navigationController?.pushViewController(collatorsView.controller, animated: true)
    }
}
