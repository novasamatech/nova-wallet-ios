import Foundation

final class StackingRewardFiltersPresenter {
    weak var view: StackingRewardFiltersViewProtocol?
    let wireframe: StackingRewardFiltersWireframeProtocol
    let interactor: StackingRewardFiltersInteractorInputProtocol

    init(
        interactor: StackingRewardFiltersInteractorInputProtocol,
        wireframe: StackingRewardFiltersWireframeProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
    }
}

extension StackingRewardFiltersPresenter: StackingRewardFiltersPresenterProtocol {
    func setup() {
        let period = StackingRewardFiltersPeriod.allTime
        view?.didReceive(viewModel: period)
    }

    func save(_: StackingRewardFiltersPeriod) {
        // TODO:
        wireframe.close(view: view)
    }
}

extension StackingRewardFiltersPresenter: StackingRewardFiltersInteractorOutputProtocol {}
