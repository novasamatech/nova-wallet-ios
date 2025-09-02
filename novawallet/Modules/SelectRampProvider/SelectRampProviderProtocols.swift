import Foundation

protocol SelectRampProviderViewProtocol: ControllerBackedProtocol {
    func didReceive(_ viewModel: SelectRampProvider.ViewModel)
}

protocol SelectRampProviderPresenterProtocol: AnyObject {
    func setup()
    func selectProvider(with id: String)
}

protocol SelectRampProviderInteractorInputProtocol: AnyObject {
    func setup()
}

protocol SelectRampProviderInteractorOutputProtocol: AnyObject {
    func didReceive(_ rampActions: [RampAction])
}

protocol SelectRampProviderWireframeProtocol: AnyObject,
    AlertPresentable,
    RampPresentable,
    RampFlowManaging {
    func openRampProvider(
        from view: (any ControllerBackedProtocol)?,
        for action: RampAction,
        locale: Locale
    )
}
