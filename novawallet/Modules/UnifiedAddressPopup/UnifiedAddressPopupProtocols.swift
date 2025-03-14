protocol UnifiedAddressPopupViewProtocol: ControllerBackedProtocol {
    func didReceive(_ viewModel: UnifiedAddressPopup.ViewModel)
}

protocol UnifiedAddressPopupPresenterProtocol: AnyObject {
    func setup()
    func copyNewAddress()
    func copyLegacyAddress()
    func close()
}

protocol UnifiedAddressPopupInteractorInputProtocol: AnyObject {
    func setup()
    func setDontShow(_ value: Bool)
}

protocol UnifiedAddressPopupInteractorOutputProtocol: AnyObject {
    func didReceiveDontShow(_ value: Bool)
}

protocol UnifiedAddressPopupWireframeProtocol: AnyObject, CopyAddressPresentable {
    func close(from view: ControllerBackedProtocol?)
}
