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
        let period = StackingRewardFiltersViewModel(period: .allTime)
        view?.didReceive(viewModel: period)
    }
}

extension StackingRewardFiltersPresenter: StackingRewardFiltersInteractorOutputProtocol {}
