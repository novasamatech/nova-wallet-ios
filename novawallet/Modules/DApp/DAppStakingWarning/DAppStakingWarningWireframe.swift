import Foundation

final class DAppStakingWarningWireframe: DAppStakingWarningWireframeProtocol {
    weak var delegate: DAppStakingWarningViewDelegate?
    let blockedURL: URL

    init(delegate: DAppStakingWarningViewDelegate?, blockedURL: URL) {
        self.delegate = delegate
        self.blockedURL = blockedURL
    }

    func complete(from view: DAppStakingWarningViewProtocol?, goToStake: Bool) {
        view?.controller.dismiss(animated: true) { [weak self] in
            guard let self else { return }

            if goToStake {
                self.delegate?.dappStakingWarningDidSelectGoToStake()
            } else {
                self.delegate?.dappStakingWarningDidSelectContinue(to: self.blockedURL)
            }
        }
    }
}
