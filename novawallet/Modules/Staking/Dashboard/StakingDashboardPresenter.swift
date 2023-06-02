import Foundation

final class StakingDashboardPresenter {
    weak var view: StakingDashboardViewProtocol?
    let wireframe: StakingDashboardWireframeProtocol
    let interactor: StakingDashboardInteractorInputProtocol

    init(
        interactor: StakingDashboardInteractorInputProtocol,
        wireframe: StakingDashboardWireframeProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
    }
}

extension StakingDashboardPresenter: StakingDashboardPresenterProtocol {
    func setup() {}
}

extension StakingDashboardPresenter: StakingDashboardInteractorOutputProtocol {}