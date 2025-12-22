import Foundation

protocol GiftPrepareShareViewProtocol: ControllerBackedProtocol {
    func didReceive(viewModel: GiftPrepareViewModel)
    func didReceive(reclaimLoading: Bool)
}

protocol GiftPrepareSharePresenterProtocol: AnyObject {
    func setup()
    func actionShare()
    func actionReclaim()
}

protocol GiftPrepareShareInteractorInputProtocol: AnyObject {
    func setup()
    func reclaim(gift: GiftModel)
    func share(
        gift: GiftModel,
        chainAsset: ChainAsset
    )
}

protocol GiftPrepareShareInteractorOutputProtocol: AnyObject {
    func didReceive(_ data: GiftPrepareShareInteractorOutputData)
    func didReceive(_ sharingPayload: GiftSharingPayload)
    func didReceiveClaimSuccess()
    func didReceive(_ error: Error)
}

protocol GiftPrepareShareWireframeProtocol: AlertPresentable,
    SharingPresentable,
    ErrorPresentable,
    ModalAlertPresenting,
    CommonRetryable {
    func completeReclaim(
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
