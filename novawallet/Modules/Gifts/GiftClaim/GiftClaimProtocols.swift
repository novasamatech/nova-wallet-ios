protocol GiftClaimViewProtocol: ControllerBackedProtocol {
    func didReceive(viewModel: GiftClaimViewModel)
}

protocol GiftClaimPresenterProtocol: AnyObject {
    func setup()
    func actionClaim()
    func actionSelectWallet()
}

protocol GiftClaimInteractorInputProtocol: AnyObject {}

protocol GiftClaimInteractorOutputProtocol: AnyObject {}

protocol GiftClaimWireframeProtocol: AnyObject {}
