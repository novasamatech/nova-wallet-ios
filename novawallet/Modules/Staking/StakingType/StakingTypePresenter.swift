import Foundation

final class StakingTypePresenter {
    weak var view: StakingTypeViewProtocol?
    let wireframe: StakingTypeWireframeProtocol
    let interactor: StakingTypeInteractorInputProtocol

    init(
        interactor: StakingTypeInteractorInputProtocol,
        wireframe: StakingTypeWireframeProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
    }
}

extension StakingTypePresenter: StakingTypePresenterProtocol {
    func setup() {}
}

extension StakingTypePresenter: StakingTypeInteractorOutputProtocol {}
