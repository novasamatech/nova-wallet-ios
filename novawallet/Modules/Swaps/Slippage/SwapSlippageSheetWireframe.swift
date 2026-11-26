import Foundation

final class SwapSlippageSheetWireframe: SwapSlippageWireframeProtocol {
    func close(from view: ControllerBackedProtocol?) {
        view?.controller.presentingViewController?.dismiss(animated: true)
    }
}
