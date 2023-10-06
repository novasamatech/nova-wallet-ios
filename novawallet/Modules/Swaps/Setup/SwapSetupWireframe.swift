import Foundation

final class SwapSetupWireframe: SwapSetupWireframeProtocol {
    let assetListObservable: AssetListModelObservable

    init(assetListObservable: AssetListModelObservable) {
        self.assetListObservable = assetListObservable
    }

    func showPayTokenSelection(
        from view: ControllerBackedProtocol?,
        completionHandler: @escaping (ChainAsset) -> Void
    ) {
        guard let selectTokenView = SwapAssetsOperationViewFactory.createSelectPayTokenView(
            for: assetListObservable,
            selectClosure: completionHandler
        ) else {
            return
        }

        view?.controller.navigationController?.pushViewController(selectTokenView.controller, animated: true)
    }

    func showReceiveTokenSelection(
        from view: ControllerBackedProtocol?,
        completionHandler: @escaping (ChainAsset) -> Void
    ) {
        guard let selectTokenView = SwapAssetsOperationViewFactory.createSelectReceiveTokenView(
            for: assetListObservable,
            selectClosure: completionHandler
        ) else {
            return
        }

        view?.controller.navigationController?.pushViewController(selectTokenView.controller, animated: true)
    }
}
