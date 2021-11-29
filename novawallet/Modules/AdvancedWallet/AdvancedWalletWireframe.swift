import Foundation

final class AdvancedWalletWireframe: AdvancedWalletWireframeProtocol {
    func presentCryptoTypeSelection(
        from view: AdvancedWalletViewProtocol?,
        availableTypes: [MultiassetCryptoType],
        selectedType: MultiassetCryptoType,
        delegate: ModalPickerViewControllerDelegate?
    ) {
        guard let modalPicker = ModalPickerFactory.createPickerForList(
            availableTypes,
            selectedType: selectedType,
            delegate: delegate,
            context: nil
        ) else {
            return
        }

        view?.controller.navigationController?.present(
            modalPicker,
            animated: true,
            completion: nil
        )
    }

    func complete(from view: AdvancedWalletViewProtocol?) {
        view?.controller.presentingViewController?.dismiss(animated: true, completion: nil)
    }
}
