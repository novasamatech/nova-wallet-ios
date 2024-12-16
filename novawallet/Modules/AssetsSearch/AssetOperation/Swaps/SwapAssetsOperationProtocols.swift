protocol SwapAssetsOperationWireframeProtocol: AssetsSearchWireframeProtocol, ErrorPresentable,
    AlertPresentable, CommonRetryable {
    func showSelectNetwork(
        from view: ControllerBackedProtocol?,
        multichainToken: MultichainToken,
        selectClosure: @escaping (ChainAsset) -> Void,
        selectClosureStrategy: SubmoduleNavigationStrategy
    )
}

protocol SwapAssetsOperationPresenterProtocol: AssetsSearchInteractorOutputProtocol {
    func directionsLoaded()
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
