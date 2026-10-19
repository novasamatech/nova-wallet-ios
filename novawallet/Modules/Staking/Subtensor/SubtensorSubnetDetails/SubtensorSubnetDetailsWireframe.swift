import UIKit

final class SubtensorSubnetDetailsWireframe: SubtensorSubnetPickerCompleting, SubtensorCallerPopping {
    let state: SubtensorSharedStateProtocol

    init(state: SubtensorSharedStateProtocol) {
        self.state = state
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
        switch host {
        case .picker:
            complete(from: view, target: target, validator: validator, delegate: delegate)
        case .pushed:
            popToCaller(from: view)
            delegate?.didSelectStakeTarget(target, validator: validator)
        }
    }
}
