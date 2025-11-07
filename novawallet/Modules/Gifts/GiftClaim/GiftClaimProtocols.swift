protocol GiftClaimViewProtocol: ControllerBackedProtocol {
    func didReceive(viewModel: GiftClaimViewModel)
}

protocol GiftClaimPresenterProtocol: AnyObject {
    func setup()
    func actionClaim()
    func actionSelectWallet()
}

protocol GiftClaimInteractorInputProtocol: AnyObject {
    func setup()
}

protocol GiftClaimInteractorOutputProtocol: AnyObject {
    func didReceive(_ error: Error)
}

protocol GiftClaimWireframeProtocol: AnyObject {}
