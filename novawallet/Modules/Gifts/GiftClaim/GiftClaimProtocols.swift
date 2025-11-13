import Foundation

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
    func actionManageWallets()
    func endUnpacking()
}

protocol GiftClaimInteractorInputProtocol: AnyObject {
    func setup()
    func changeWallet(to wallet: MetaAccountModel)
    func claimGift(with giftDescription: ClaimableGiftDescription)
}

protocol GiftClaimInteractorOutputProtocol: AnyObject {
    func didClaimSuccessfully()
    func didReceive(_ claimSetupResult: GiftClaimInteractor.ClaimSetupResult)
    func didReceive(_ error: Error)
}

protocol GiftClaimWireframeProtocol: AlertPresentable,
    ErrorPresentable,
    GiftWalletChoosePresentable,
    ModalAlertPresenting,
    CommonRetryable
{
    func showManageWallets(from view: ControllerBackedProtocol?)

    func complete(
        from view: ControllerBackedProtocol?,
        with successText: String
    )

    func showError(
        from view: ControllerBackedProtocol?,
        title: String,
        message: String,
        actionTitle: String
    )

    func showRetryableError(
        from view: ControllerBackedProtocol?,
        locale: Locale,
        retryAction: @escaping () -> Void
    )
}
