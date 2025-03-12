protocol SelectRampProviderViewProtocol: ControllerBackedProtocol {
    func didReceive(_ viewModel: SelectRampProvider.ViewModel)
}

protocol SelectRampProviderPresenterProtocol: AnyObject {
    func setup()
}

protocol SelectRampProviderInteractorInputProtocol: AnyObject {
    func setup()
}

protocol SelectRampProviderInteractorOutputProtocol: AnyObject {
    func didReceive(_ rampActions: [RampAction])
}

protocol SelectRampProviderWireframeProtocol: AnyObject {}
