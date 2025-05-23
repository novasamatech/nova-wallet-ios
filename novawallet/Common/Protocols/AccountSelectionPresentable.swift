import Foundation_iOS

protocol AccountSelectionPresentable: AnyObject {
    func presentAccountSelection(
        _ accounts: [MetaChainAccountResponse],
        selectedAccountItem: MetaChainAccountResponse?,
        title: LocalizableResource<String>,
        delegate: ModalPickerViewControllerDelegate,
        from view: ControllerBackedProtocol?,
        context: AnyObject?
    )
}

extension AccountSelectionPresentable {
    func presentAccountSelection(
        _ accounts: [MetaChainAccountResponse],
        selectedAccountItem: MetaChainAccountResponse?,
        title: LocalizableResource<String>,
        delegate: ModalPickerViewControllerDelegate,
        from view: ControllerBackedProtocol?,
        context: AnyObject?
    ) {
        guard let picker = ModalPickerFactory.createPickerList(
            accounts,
            selectedAccount: selectedAccountItem,
            title: title,
            delegate: delegate,
            context: context
        ) else {
            return
        }

        view?.controller.present(
            picker,
            animated: true,
            completion: nil
        )
    }
}
