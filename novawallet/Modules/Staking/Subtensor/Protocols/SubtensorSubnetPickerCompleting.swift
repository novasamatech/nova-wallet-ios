import UIKit

protocol SubtensorSubnetPickerCompleting {
    func complete(
        from view: ControllerBackedProtocol?,
        target: SubtensorStakeTarget,
        validator: SubtensorValidatorDirectoryItem?,
        recommendedHotkey: AccountId?,
        delegate: SubtensorSubnetSelectDelegate?
    )
}

extension SubtensorSubnetPickerCompleting {
    func complete(
        from view: ControllerBackedProtocol?,
        target: SubtensorStakeTarget,
        validator: SubtensorValidatorDirectoryItem?,
        recommendedHotkey: AccountId?,
        delegate: SubtensorSubnetSelectDelegate?
    ) {
        let deliver: () -> Void = {
            delegate?.didSelectStakeTarget(target, validator: validator, recommendedHotkey: recommendedHotkey)
        }

        guard let presenting = view?.controller.navigationController?.presentingViewController else {
            deliver()
            return
        }

        presenting.dismiss(animated: true, completion: deliver)
    }
}
