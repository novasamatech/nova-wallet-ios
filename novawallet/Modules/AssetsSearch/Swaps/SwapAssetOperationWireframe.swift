import UIKit
import SoraUI

final class SwapAssetsOperationWireframe: SwapAssetsOperationWireframeProtocol {}

extension SwapAssetsOperationWireframe: AssetsSearchWireframeProtocol {
    func close(view: AssetsSearchViewProtocol?) {
        view?.controller.presentingViewController?.dismiss(animated: true)
    }
}
