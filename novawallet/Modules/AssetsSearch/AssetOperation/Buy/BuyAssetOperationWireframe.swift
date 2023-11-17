import UIKit
import SoraUI

protocol BuyAssetOperationWireframeProtocol: AssetsSearchWireframeProtocol, MessageSheetPresentable, PurchasePresentable, AlertPresentable {}

final class BuyAssetOperationWireframe: BuyAssetOperationWireframeProtocol {}

extension BuyAssetOperationWireframe: AssetsSearchWireframeProtocol {
    func close(view: AssetsSearchViewProtocol?) {
        view?.controller.presentingViewController?.dismiss(animated: true)
    }
}
