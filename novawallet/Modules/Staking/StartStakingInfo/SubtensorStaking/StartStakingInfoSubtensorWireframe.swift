import Foundation

final class StartStakingInfoSubtensorWireframe: StartStakingInfoWireframe,
    StartStakingInfoSubtensorWireframeProtocol {
    let state: SubtensorStakingSharedStateProtocol

    weak var subnetSelectDelegate: SubtensorSubnetSelectDelegate?

    init(state: SubtensorStakingSharedStateProtocol) {
        self.state = state
    }

    override func showSetupAmount(from view: ControllerBackedProtocol?) {
        guard
            let subnetSelectDelegate,
            let picker = SubtensorSubnetSelectViewFactory.createPicker(
                for: state,
                delegate: subnetSelectDelegate
            ) else {
            return
        }

        view?.controller.presentWithCardLayout(picker, animated: true)
    }

    func showRootDetails(from view: ControllerBackedProtocol?) {
        guard let setupView = SubtensorStakingSetupViewFactory.createRootDetailsView(for: state) else {
            return
        }

        view?.controller.navigationController?.pushViewController(
            setupView.controller,
            animated: true
        )
    }

    func showSubnetSetup(
        from view: ControllerBackedProtocol?,
        target: SubtensorStakeTarget,
        validator: SubtensorValidatorDirectoryItem?
    ) {
        guard let setupView = SubtensorStakingSetupViewFactory.createSubnetView(
            for: state,
            target: target,
            validator: validator
        ) else {
            return
        }

        view?.controller.navigationController?.pushViewController(
            setupView.controller,
            animated: true
        )
    }
}
