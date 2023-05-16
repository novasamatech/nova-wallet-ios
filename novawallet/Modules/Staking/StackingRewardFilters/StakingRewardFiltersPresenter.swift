import Foundation

final class StakingRewardFiltersPresenter {
    weak var view: StakingRewardFiltersViewProtocol?
    let wireframe: StakingRewardFiltersWireframeProtocol
    let interactor: StakingRewardFiltersInteractorInputProtocol

    init(
        interactor: StakingRewardFiltersInteractorInputProtocol,
        wireframe: StakingRewardFiltersWireframeProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
    }
}

extension StakingRewardFiltersPresenter: StakingRewardFiltersPresenterProtocol {
    func setup() {
        let period = StakingRewardFiltersPeriod.allTime
        view?.didReceive(viewModel: period)
    }

    func save(_: StakingRewardFiltersPeriod) {
        // TODO:
        wireframe.close(view: view)
    }
}

extension StakingRewardFiltersPresenter: StakingRewardFiltersInteractorOutputProtocol {}
