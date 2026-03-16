import Foundation

final class DAppStakingWarningPresenter {
    weak var view: DAppStakingWarningViewProtocol?
    let wireframe: DAppStakingWarningWireframeProtocol

    init(wireframe: DAppStakingWarningWireframeProtocol) {
        self.wireframe = wireframe
    }
}

extension DAppStakingWarningPresenter: DAppStakingWarningPresenterProtocol {
    func setup() {}

    func goToStake() {
        wireframe.complete(from: view, goToStake: true)
    }

    func showAdvanced() {
        view?.showContinueOption()
    }

    func continueToSite() {
        wireframe.complete(from: view, goToStake: false)
    }
}
