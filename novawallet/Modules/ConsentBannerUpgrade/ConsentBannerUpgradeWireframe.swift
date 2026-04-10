import Foundation

final class ConsentBannerUpgradeWireframe: ConsentBannerUpgradeWireframeProtocol {
    func close(view: ConsentBannerUpgradeViewProtocol?, completion: (() -> Void)?) {
        view?.controller.dismiss(animated: true, completion: completion)
    }
}
