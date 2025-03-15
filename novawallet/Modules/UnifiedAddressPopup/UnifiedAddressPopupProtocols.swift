protocol UnifiedAddressPopupViewProtocol: ControllerBackedProtocol {
    func didReceive(_ viewModel: UnifiedAddressPopup.ViewModel)
}

protocol UnifiedAddressPopupPresenterProtocol: AnyObject {
    func setup()
    func copyNewAddress()
    func copyLegacyAddress()
    func close()
    func toggleHide()
}

protocol UnifiedAddressPopupInteractorInputProtocol: AnyObject {
    func setup()
    func setDontShow(_ value: Bool)
}

protocol UnifiedAddressPopupInteractorOutputProtocol: AnyObject {
    func didReceiveDontShow(_ value: Bool)
}

protocol UnifiedAddressPopupWireframeProtocol: AnyObject,
    ModalAlertPresenting,
    CopyAddressPresentable {
    func close(from view: ControllerBackedProtocol?)
}

protocol UnifiedAddressPopupPresentable {
    func presentUnifiedAddressPopup(
        from view: ControllerBackedProtocol?,
        newAddress: AccountAddress,
        legacyAddress: AccountAddress
    )
}

extension UnifiedAddressPopupPresentable {
    func presentUnifiedAddressPopup(
        from view: ControllerBackedProtocol?,
        newAddress: AccountAddress,
        legacyAddress: AccountAddress
    ) {
        guard let popupView = UnifiedAddressPopupViewFactory.createView(
            newAddress: newAddress,
            legacyAddress: legacyAddress
        ) else {
            return
        }

        view?.controller.present(
            popupView.controller,
            animated: true
        )
    }
}
