import Foundation

final class MythosStkClaimRewardsPresenter {
    weak var view: MythosStkClaimRewardsViewProtocol?
    let wireframe: MythosStkClaimRewardsWireframeProtocol
    let interactor: MythosStkClaimRewardsInteractorInputProtocol

    init(
        interactor: MythosStkClaimRewardsInteractorInputProtocol,
        wireframe: MythosStkClaimRewardsWireframeProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
    }
}

extension MythosStkClaimRewardsPresenter: MythosStkClaimRewardsPresenterProtocol {
    func setup() {}
}

extension MythosStkClaimRewardsPresenter: MythosStkClaimRewardsInteractorOutputProtocol {}
