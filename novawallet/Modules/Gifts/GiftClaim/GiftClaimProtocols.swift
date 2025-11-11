protocol GiftClaimViewProtocol: ControllerBackedProtocol {
    func didReceive(viewModel: GiftClaimViewModel)
    func didReceiveUnpacking(viewModel: LottieAnimationFrameRange)
    func didStartLoading()
    func didStopLoading()
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
    func didReceive(_ claimSetupResult: GiftClaimInteractor.ClaimSetupResult)
    func didReceive(_ error: Error)
}

protocol GiftClaimWireframeProtocol: AlertPresentable, ErrorPresentable {}
