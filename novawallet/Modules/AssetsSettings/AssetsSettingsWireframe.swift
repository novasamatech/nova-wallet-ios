import Foundation

final class AssetsSettingsWireframe: AssetsSettingsWireframeProtocol {
    func close(view: AssetsSettingsViewProtocol?) {
        view?.controller.presentingViewController?.dismiss(animated: true, completion: nil)
    }
}
