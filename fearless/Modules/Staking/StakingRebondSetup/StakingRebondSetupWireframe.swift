import Foundation

final class StakingRebondSetupWireframe: StakingRebondSetupWireframeProtocol {
    let state: StakingSharedState

    init(state: StakingSharedState) {
        self.state = state
    }

    func proceed(view: StakingRebondSetupViewProtocol?, amount: Decimal) {
        guard let rebondView = StakingRebondConfirmationViewFactory.createView(
            for: .custom(amount: amount),
            state: state
        ) else {
            return
        }

        view?.controller.navigationController?.pushViewController(
            rebondView.controller,
            animated: true
        )
    }

    func close(view: StakingRebondSetupViewProtocol?) {
        view?.controller.presentingViewController?.dismiss(animated: true, completion: nil)
    }
}
