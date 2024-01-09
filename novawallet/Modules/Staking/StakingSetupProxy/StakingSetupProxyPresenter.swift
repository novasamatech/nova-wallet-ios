import Foundation

final class StakingSetupProxyPresenter {
    weak var view: StakingSetupProxyViewProtocol?
    let wireframe: StakingSetupProxyWireframeProtocol
    let interactor: StakingSetupProxyInteractorInputProtocol

    init(
        interactor: StakingSetupProxyInteractorInputProtocol,
        wireframe: StakingSetupProxyWireframeProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
    }
}

extension StakingSetupProxyPresenter: StakingSetupProxyPresenterProtocol {
    func setup() {}
    func complete(authority _: String) {}
    func showDepositInfo() {}
}

extension StakingSetupProxyPresenter: StakingSetupProxyInteractorOutputProtocol {}
