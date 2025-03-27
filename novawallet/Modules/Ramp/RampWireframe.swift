import Foundation

import SoraFoundation

final class RampWireframe: RampWireframeProtocol {
    private weak var delegate: RampDelegate?

    init(delegate: RampDelegate?) {
        self.delegate = delegate
    }

    func complete(
        from view: RampViewProtocol?,
        with action: RampActionType
    ) {
        view?.controller.presentingViewController?.dismiss(animated: true) {
            DispatchQueue.main.async {
                self.delegate?.rampDidComplete(action: action)
            }
        }
    }
}

protocol RampDelegate: AnyObject {
    func rampDidComplete(action: RampActionType)
}
