import Foundation

final class SubtensorSubnetSelectWireframe: SubtensorSubnetSelectWireframeProtocol {
    func complete(from view: SubtensorSubnetSelectViewProtocol?) {
        view?.controller.navigationController?.popViewController(animated: true)
    }
}
