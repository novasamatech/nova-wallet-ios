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
    func claimGift(with giftDescription: ClaimableGiftDescription)
}

protocol GiftClaimInteractorOutputProtocol: AnyObject {
    func didClaimSuccessfully()
    func didReceive(_ giftDescription: ClaimableGiftDescription)
    func didReceive(_ error: Error)
}

protocol GiftClaimWireframeProtocol: AlertPresentable, ErrorPresentable {}
