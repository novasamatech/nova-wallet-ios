import Foundation

final class SwapSlippageWireframe: SwapSlippageWireframeProtocol {
    func close(from view: ControllerBackedProtocol?) {
        view?.controller.navigationController?.popViewController(animated: true)
    }
}
