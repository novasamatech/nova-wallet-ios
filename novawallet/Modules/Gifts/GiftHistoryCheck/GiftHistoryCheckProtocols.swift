protocol GiftHistoryCheckViewProtocol: ControllerBackedProtocol {
    func didReceive(_ loading: Bool)
}

protocol GiftHistoryCheckPresenterProtocol: AnyObject {
    func setup()
}

protocol GiftHistoryCheckInteractorInputProtocol: AnyObject {
    func setup()
    func fetchGifts()
}

protocol GiftHistoryCheckInteractorOutputProtocol: AnyObject {
    func didReceive(_ gifts: [GiftModel])
    func didReceive(_ error: Error)
}

protocol GiftHistoryCheckWireframeProtocol: AlertPresentable, CommonRetryable {
    func showOnboarding(from view: ControllerBackedProtocol?)

    func showHistory(
        from view: ControllerBackedProtocol?,
        gifts: [GiftModel]
    )
}
