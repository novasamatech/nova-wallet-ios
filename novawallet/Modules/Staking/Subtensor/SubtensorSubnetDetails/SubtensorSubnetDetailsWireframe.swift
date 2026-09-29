import UIKit

final class SubtensorSubnetDetailsWireframe: SubtensorSubnetPickerCompleting {
    let state: SubtensorStakingSharedStateProtocol

    init(state: SubtensorStakingSharedStateProtocol) {
        self.state = state
    }
}

private extension SubtensorSubnetDetailsWireframe {
    func finish(
        from view: SubtensorSubnetDetailsViewProtocol?,
        host: SubtensorSubnetDetailsHost,
        target: SubtensorStakeTarget,
        validator: SubtensorValidatorDirectoryItem?,
        delegate: SubtensorSubnetSelectDelegate?
    ) {
        switch host {
        case .picker:
            complete(from: view, target: target, validator: validator, delegate: delegate)
        case .pushed:
            popToCaller(from: view)
            delegate?.didSelectStakeTarget(target, validator: validator)
        }
    }

    func popToCaller(from view: SubtensorSubnetDetailsViewProtocol?) {
        guard
            let controller = view?.controller,
            let navigationController = controller.navigationController,
            let index = navigationController.viewControllers.firstIndex(of: controller),
            index > 0 else {
            return
        }

        navigationController.popToViewController(navigationController.viewControllers[index - 1], animated: true)
    }
}

extension SubtensorSubnetDetailsWireframe: SubtensorSubnetDetailsWireframeProtocol {
    func showValidators(
        from view: SubtensorSubnetDetailsViewProtocol?,
        target: SubtensorStakeTarget,
        selectedHotkey: AccountId?,
        delegate: SubtensorValidatorSelectDelegate
    ) {
        guard let validatorsView = SubtensorValidatorSelectViewFactory.createView(
            for: state,
            target: target,
            selectedHotkey: selectedHotkey,
            delegate: delegate
        ) else {
            return
        }

        view?.controller.navigationController?.pushViewController(validatorsView.controller, animated: true)
    }

    func complete(
        from view: SubtensorSubnetDetailsViewProtocol?,
        host: SubtensorSubnetDetailsHost,
        target: SubtensorStakeTarget,
        validator: SubtensorValidatorDirectoryItem?,
        delegate: SubtensorSubnetSelectDelegate?
    ) {
        guard
            let controller = view?.controller,
            let navigationController = controller.navigationController,
            navigationController.topViewController !== controller else {
            finish(from: view, host: host, target: target, validator: validator, delegate: delegate)
            return
        }

        DispatchQueue.main.async {
            guard let coordinator = navigationController.transitionCoordinator else {
                self.finish(from: view, host: host, target: target, validator: validator, delegate: delegate)
                return
            }

            coordinator.animate(alongsideTransition: nil) { _ in
                self.finish(from: view, host: host, target: target, validator: validator, delegate: delegate)
            }
        }
    }
}
