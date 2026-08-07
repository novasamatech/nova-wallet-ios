import Foundation

final class DAppStakingNoticeWireframe: DAppStakingNoticeWireframeProtocol {
    weak var delegate: DAppStakingNoticeDelegate?

    func complete(from view: DAppStakingNoticeViewProtocol?) {
        view?.controller.dismiss(animated: true) { [weak delegate] in
            delegate?.dappStakingNoticeDidSelectContinue()
        }
    }
}
