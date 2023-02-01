protocol DelegateInfoDetailsViewProtocol: ControllerBackedProtocol {
    func didReceive(delegateName: String)
    func didReceive(delegateInfo: String)
}

protocol DelegateInfoDetailsPresenterProtocol: AnyObject {
    func setup()
}
