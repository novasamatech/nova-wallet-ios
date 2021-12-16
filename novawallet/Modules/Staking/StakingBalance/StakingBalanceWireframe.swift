final class StakingBalanceWireframe: StakingBalanceWireframeProtocol {
    let state: StakingSharedState

    init(state: StakingSharedState) {
        self.state = state
    }

    func showBondMore(from view: ControllerBackedProtocol?) {
        guard let bondMoreView = StakingBondMoreViewFactory.createView(from: state) else { return }
        let navigationController = ImportantFlowViewFactory.createNavigation(from: bondMoreView.controller)
        view?.controller.present(navigationController, animated: true, completion: nil)
    }

    func showUnbond(from view: ControllerBackedProtocol?) {
        guard let unbondView = StakingUnbondSetupViewFactory.createView(for: state) else {
            return
        }

        let navigationController = ImportantFlowViewFactory.createNavigation(from: unbondView.controller)

        view?.controller.present(navigationController, animated: true, completion: nil)
    }

    func showRedeem(from view: ControllerBackedProtocol?) {
        guard let redeemView = StakingRedeemViewFactory.createView(for: state) else {
            return
        }

        let navigationController = ImportantFlowViewFactory.createNavigation(from: redeemView.controller)

        view?.controller.present(navigationController, animated: true, completion: nil)
    }

    func showRebond(from view: ControllerBackedProtocol?, option: StakingRebondOption) {
        let rebondView: ControllerBackedProtocol? = {
            switch option {
            case .all:
                return StakingRebondConfirmationViewFactory.createView(for: .all, state: state)
            case .last:
                return StakingRebondConfirmationViewFactory.createView(for: .last, state: state)
            case .customAmount:
                return StakingRebondSetupViewFactory.createView(for: state)
            }
        }()

        guard let controller = rebondView?.controller else {
            return
        }

        let navigationController = ImportantFlowViewFactory.createNavigation(from: controller)

        view?.controller.present(navigationController, animated: true, completion: nil)
    }

    func cancel(from view: ControllerBackedProtocol?) {
        view?.controller.navigationController?.popViewController(animated: true)
    }
}
