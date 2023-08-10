import Foundation

final class StakingSelectPoolPresenter {
    weak var view: StakingSelectPoolViewProtocol?
    let wireframe: StakingSelectPoolWireframeProtocol
    let interactor: StakingSelectPoolInteractorInputProtocol

    init(
        interactor: StakingSelectPoolInteractorInputProtocol,
        wireframe: StakingSelectPoolWireframeProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
    }
}

extension StakingSelectPoolPresenter: StakingSelectPoolPresenterProtocol {
    func setup() {}

    func selectPool(poolId _: NominationPools.PoolId) {}

    func showPoolInfo(poolId _: NominationPools.PoolId) {}
}

extension StakingSelectPoolPresenter: StakingSelectPoolInteractorOutputProtocol {
    func didReceive(poolStats _: [NominationPools.PoolStats]) {}
}
