import Operation_iOS

protocol GiftListViewProtocol: ControllerBackedProtocol {
    func didReceive(viewModel: GiftsOnboardingViewModel)
    func didReceive(listSections: [GiftListSectionModel])
    func didReceive(loading: Bool)
}

protocol GiftListPresenterProtocol: AnyObject {
    func setup()
    func activateLearnMore()
    func actionCreateGift()
    func selectGift(with identifier: String)
}

protocol GiftListInteractorInputProtocol: AnyObject {
    func setup()
}

protocol GiftListInteractorOutputProtocol: AnyObject {
    func didReceive(
        _ changes: [DataProviderChange<GiftModel>],
        _ chainAssets: [ChainAssetId: ChainAsset]
    )
    func didReceive(_ error: Error)
}

protocol GiftListWireframeProtocol: WebPresentable, ErrorPresentable, AlertPresentable, CommonRetryable {
    func showGift(
        _ gift: GiftModel,
        chainAsset: ChainAsset,
        from view: ControllerBackedProtocol?
    )
    func showCreateGift(from view: ControllerBackedProtocol?)
}
