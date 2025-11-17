import Operation_iOS

protocol GiftListViewProtocol: ControllerBackedProtocol {
    func didReceive(viewModel: GiftsOnboardingViewModel)
    func didReceive(loading: Bool)
}

protocol GiftListPresenterProtocol: AnyObject {
    func setup()
    func activateLearnMore()
    func actionCreateGift()
}

protocol GiftListInteractorInputProtocol: AnyObject {
    func setup()
}

protocol GiftListInteractorOutputProtocol: AnyObject {
    func didReceive(_ changes: [DataProviderChange<GiftModel>])
    func didReceive(_ error: Error)
}

protocol GiftListWireframeProtocol: WebPresentable, ErrorPresentable, AlertPresentable, CommonRetryable {
    func showCreateGift(from view: ControllerBackedProtocol?)
}
