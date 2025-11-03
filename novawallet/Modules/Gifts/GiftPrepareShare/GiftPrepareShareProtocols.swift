protocol GiftPrepareShareViewProtocol: ControllerBackedProtocol {
    func didReceive(viewModel: GiftPrepareViewModel)
}

protocol GiftPrepareSharePresenterProtocol: AnyObject {
    func setup()
    func actionShare()
}

protocol GiftPrepareShareInteractorInputProtocol: AnyObject {
    func setup()
    func share(
        gift: GiftModel,
        chainAsset: ChainAsset
    )
}

protocol GiftPrepareShareInteractorOutputProtocol: AnyObject {
    func didReceive(_ data: GiftPrepareShareInteractorOutputData)
    func didReceive(_ sharingPayload: GiftSharingPayload)
    func didReceive(_ error: Error)
}

protocol GiftPrepareShareWireframeProtocol: AlertPresentable, SharingPresentable, ErrorPresentable {}
