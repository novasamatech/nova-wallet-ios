import Foundation

final class MythosStakingSetupPresenter {
    weak var view: CollatorStakingSetupViewProtocol?
    let wireframe: MythosStakingSetupWireframeProtocol
    let interactor: MythosStakingSetupInteractorInputProtocol

    init(
        interactor: MythosStakingSetupInteractorInputProtocol,
        wireframe: MythosStakingSetupWireframeProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
    }
}

extension MythosStakingSetupPresenter: CollatorStakingSetupPresenterProtocol {
    func setup() {}
    func selectCollator() {}
    func updateAmount(_: Decimal?) {}
    func selectAmountPercentage(_: Float) {}
    func proceed() {}
}

extension MythosStakingSetupPresenter: MythosStakingSetupInteractorOutputProtocol {}
