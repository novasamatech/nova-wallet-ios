import Foundation

extension ParaStkUnstakePresenter: ModalPickerViewControllerDelegate {
    func modalPickerDidSelectModelAtIndex(_ index: Int, context: AnyObject?) {
        guard
            let delegations = context as? [ParachainStaking.Bond],
            let disabledCollators = scheduledRequests?.map(\.collatorId) else {
            return
        }

        let collatorId = delegations[index].owner

        if !disabledCollators.contains(collatorId) {
            let displayName = delegationIdentities?[collatorId]?.displayName
            changeCollator(with: collatorId, name: displayName)
        } else {
            let title = R.string(preferredLanguages: selectedLocale.rLanguages
            ).localizable.parastkCantUnstakeTitle()

            let message = R.string(preferredLanguages: selectedLocale.rLanguages
            ).localizable.parastkCantUnstakeMessage()

            let close = R.string(preferredLanguages: selectedLocale.rLanguages).localizable.commonClose()

            wireframe.present(message: message, title: title, closeAction: close, from: view)
        }
    }
}
