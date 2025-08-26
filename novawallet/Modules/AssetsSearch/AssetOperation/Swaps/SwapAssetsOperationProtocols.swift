protocol SwapAssetsOperationWireframeProtocol: AssetsSearchWireframeProtocol, ErrorPresentable,
    AlertPresentable, CommonRetryable {
    func showSelectNetwork(
        from view: ControllerBackedProtocol?,
        multichainToken: MultichainToken
    )
}

protocol SwapAssetsOperationPresenterProtocol: AssetsSearchInteractorOutputProtocol {
    func didUpdate(hasDirections: Bool)
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
