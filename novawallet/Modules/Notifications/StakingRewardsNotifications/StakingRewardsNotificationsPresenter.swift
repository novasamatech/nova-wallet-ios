import Foundation

final class StakingRewardsNotificationsPresenter {
    weak var view: StakingRewardsNotificationsViewProtocol?
    let wireframe: StakingRewardsNotificationsWireframeProtocol
    let interactor: StakingRewardsNotificationsInteractorInputProtocol

    init(
        interactor: StakingRewardsNotificationsInteractorInputProtocol,
        wireframe: StakingRewardsNotificationsWireframeProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
    }
}

extension StakingRewardsNotificationsPresenter: StakingRewardsNotificationsPresenterProtocol {
    func setup() {
        let mockModels: [StakingRewardsNotificationsViewModel] = [
            .init(icon: nil, name: "Bifrost Kusama OpenGov", enabled: true),
            .init(icon: nil, name: "Moonriver OpenGov", enabled: true),
            .init(icon: nil, name: "KILT", enabled: true),
            .init(icon: nil, name: "Karura", enabled: true)
        ]

        view?.didReceive(viewModels: mockModels)
    }

    func clear() {}

    func changeSettings(network _: String, isEnabled _: Bool) {}
}

extension StakingRewardsNotificationsPresenter: StakingRewardsNotificationsInteractorOutputProtocol {}
