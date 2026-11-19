import Foundation

final class SwapTokenSelectNetworksWireframe: SwapTokenSelectNetworksWireframeProtocol {
    func close(view: SwapTokenSelectNetworksViewProtocol?) {
        view?.controller.dismiss(animated: true)
    }
}
