import Foundation

final class DAppStakingNoticePresenter {
    weak var view: DAppStakingNoticeViewProtocol?
    let wireframe: DAppStakingNoticeWireframeProtocol

    init(wireframe: DAppStakingNoticeWireframeProtocol) {
        self.wireframe = wireframe
    }
}

// MARK: DAppStakingNoticePresenterProtocol

extension DAppStakingNoticePresenter: DAppStakingNoticePresenterProtocol {
    func setup() {}

    func goToStaking() {
        wireframe.redirectToStaking(from: view)
    }

    func continueToSite() {
        wireframe.complete(from: view)
    }
}
