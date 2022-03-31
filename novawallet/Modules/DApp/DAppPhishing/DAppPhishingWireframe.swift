import Foundation

final class DAppPhishingWireframe: DAppPhishingWireframeProtocol {
    weak var delegate: DAppPhishingViewDelegate?

    func complete(from view: DAppPhishingViewProtocol?) {
        view?.controller.dismiss(animated: true) {
            self.delegate?.dappPhishingViewDidHide()
        }
    }
}
