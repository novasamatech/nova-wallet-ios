protocol TokensManageViewProtocol: ControllerBackedProtocol {
    func didReceive(viewModels: [TokensManageViewModel])
}

protocol TokensManagePresenterProtocol: AnyObject {
    func setup()
    func performAddToken()
    func performEdit(for viewModel: TokensManageViewModel)
    func performSwitch(for viewModel: TokensManageViewModel, isOn: Bool)
}

protocol TokensManageInteractorInputProtocol: AnyObject {}

protocol TokensManageInteractorOutputProtocol: AnyObject {}

protocol TokensManageWireframeProtocol: AnyObject {}
