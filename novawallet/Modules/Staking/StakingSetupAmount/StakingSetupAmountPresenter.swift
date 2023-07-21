import Foundation

final class StakingSetupAmountPresenter {
    weak var view: StakingSetupAmountViewProtocol?
    let wireframe: StakingSetupAmountWireframeProtocol
    let interactor: StakingSetupAmountInteractorInputProtocol

    init(
        interactor: StakingSetupAmountInteractorInputProtocol,
        wireframe: StakingSetupAmountWireframeProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
    }
}

extension StakingSetupAmountPresenter: StakingSetupAmountPresenterProtocol {
    func setup() {}
}

extension StakingSetupAmountPresenter: StakingSetupAmountInteractorOutputProtocol {}
