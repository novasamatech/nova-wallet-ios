import Foundation

final class StakingMoreOptionsPresenter {
    weak var view: StakingMoreOptionsViewProtocol?
    let wireframe: StakingMoreOptionsWireframeProtocol
    let interactor: StakingMoreOptionsInteractorInputProtocol

    init(
        interactor: StakingMoreOptionsInteractorInputProtocol,
        wireframe: StakingMoreOptionsWireframeProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
    }
}

extension StakingMoreOptionsPresenter: StakingMoreOptionsPresenterProtocol {
    func setup() {}
}

extension StakingMoreOptionsPresenter: StakingMoreOptionsInteractorOutputProtocol {
    func didReceive(dAppsResult _: Result<DAppList, Error>?) {}
}
