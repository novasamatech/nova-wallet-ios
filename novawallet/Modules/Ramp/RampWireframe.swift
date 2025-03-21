import Foundation

import SoraFoundation

final class RampWireframe: RampWireframeProtocol {
    private weak var delegate: RampDelegate?

    init(delegate: RampDelegate?) {
        self.delegate = delegate
    }

    func complete(from view: RampViewProtocol?) {
        view?.controller.presentingViewController?.dismiss(animated: true) {
            DispatchQueue.main.async {
                self.delegate?.rampDidComplete()
            }
        }
    }
}

protocol RampDelegate: AnyObject {
    func rampDidComplete()
}
