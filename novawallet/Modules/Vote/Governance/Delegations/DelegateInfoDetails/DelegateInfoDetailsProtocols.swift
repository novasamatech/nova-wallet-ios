protocol DelegateInfoDetailsViewProtocol: ControllerBackedProtocol {
    func didReceive(viewModel: DelegateInfoDetailsState)
}

protocol DelegateInfoDetailsPresenterProtocol: AnyObject {
    func setup()
}
