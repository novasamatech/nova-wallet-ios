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

protocol SelectRampProviderWireframeProtocol: AnyObject {
    func openRampProvider(
        from view: ControllerBackedProtocol?,
        for action: RampAction
    )
}
