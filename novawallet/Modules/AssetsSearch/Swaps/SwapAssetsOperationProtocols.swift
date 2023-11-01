protocol SwapAssetsOperationWireframeProtocol: AssetsSearchWireframeProtocol, ErrorPresentable,
    AlertPresentable, CommonRetryable {}

protocol SwapAssetsOperationPresenterProtocol: AssetsSearchInteractorOutputProtocol {
    func didReceive(selfSufficientChainAsssets: Set<ChainAssetId>)
    func didReceive(error: SwapAssetsOperationError)
}

protocol SwapAssetsOperationInteractorInputProtocol: AssetsSearchInteractorInputProtocol {}

enum SwapAssetsOperationError: Error {
    case directions(Error)
}

protocol SwapAssetsViewProtocol: AssetsSearchViewProtocol {
    func didStartLoading()
    func didStopLoading()
}
