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
            let title = R.string.localizable.parastkCantUnstakeTitle(
                preferredLanguages: selectedLocale.rLanguages
            )

            let message = R.string.localizable.parastkCantUnstakeMessage(
                preferredLanguages: selectedLocale.rLanguages
            )

            let close = R.string.localizable.commonClose(preferredLanguages: selectedLocale.rLanguages)

            wireframe.present(message: message, title: title, closeAction: close, from: view)
        }
    }
}
