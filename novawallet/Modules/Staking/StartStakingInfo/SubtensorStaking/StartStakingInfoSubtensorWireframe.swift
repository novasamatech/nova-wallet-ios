import UIKit
import NovaAnalytics

final class StartStakingInfoSubtensorWireframe: StartStakingInfoWireframe,
    StartStakingInfoSubtensorWireframeProtocol {
    let state: SubtensorSharedStateProtocol

    let browseState = SubtensorSubnetBrowseState()

    weak var subnetSelectDelegate: SubtensorSubnetSelectDelegate?

    init(state: SubtensorSharedStateProtocol) {
        self.state = state
    }

    override func showSetupAmount(from view: ControllerBackedProtocol?) {
        let carousel = SubtensorWhereToStakeViewFactory.createView(for: state)
        view?.controller.navigationController?.pushViewController(carousel.controller, animated: true)
    }

    func showAllOptions(from view: ControllerBackedProtocol?) {
        guard
            let subnetSelectDelegate,
            let picker = SubtensorSubnetSelectViewFactory.createPicker(
                for: state,
                delegate: subnetSelectDelegate,
                browseState: browseState,
                source: .seeAllOptions
            ) else {
            return
        }

        view?.controller.presentWithCardLayout(picker, animated: true)
    }

    func showRootDetails(from view: ControllerBackedProtocol?) {
        guard let setupView = SubtensorStakeSetupViewFactory.createRootDetailsView(
            for: state, browseState: browseState
        ) else {
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
        guard let setupView = SubtensorStakeSetupViewFactory.createSubnetView(
            for: state,
            target: target,
            validator: validator,
            browseState: browseState
        ) else {
            return
        }

        view?.controller.navigationController?.pushViewController(
            setupView.controller,
            animated: true
        )
    }

    func close(from view: ControllerBackedProtocol?) {
        guard let flowPresenter = view?.controller.navigationController?.presentingViewController else {
            return
        }

        SubtensorModalStack.dismiss(above: flowPresenter, animated: false)
    }
}
