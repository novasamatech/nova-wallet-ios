import Foundation

final class ParaStkSelectCollatorsWireframe: ParaStkSelectCollatorsWireframeProtocol {
    func close(view: ParaStkSelectCollatorsViewProtocol?) {
        view?.controller.navigationController?.popToRootViewController(animated: true)
    }
}
