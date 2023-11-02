import UIKit
import SoraUI

final class SwapAssetsOperationWireframe: SwapAssetsOperationWireframeProtocol {}

extension SwapAssetsOperationWireframe: AssetsSearchWireframeProtocol {
    func close(view: AssetsSearchViewProtocol?, completion: (() -> Void)?) {
        view?.controller.presentingViewController?.dismiss(animated: true, completion: completion)
    }
}
