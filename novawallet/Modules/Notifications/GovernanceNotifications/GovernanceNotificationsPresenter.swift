import Foundation

final class GovernanceNotificationsPresenter {
    weak var view: GovernanceNotificationsViewProtocol?
    let wireframe: GovernanceNotificationsWireframeProtocol
    let interactor: GovernanceNotificationsInteractorInputProtocol

    init(
        interactor: GovernanceNotificationsInteractorInputProtocol,
        wireframe: GovernanceNotificationsWireframeProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
    }
}

extension GovernanceNotificationsPresenter: GovernanceNotificationsPresenterProtocol {
    func setup() {
        let mockModels = GovernanceNotificationsViewModel(
            extendedSettings: [
                .init(icon: nil, name: "Polkadot", settings: .init(new: true, update: true, delegate: true, tracks: "All"), enabled: true),
                .init(icon: nil, name: "Kusama", settings: .init(new: true, update: true, delegate: true, tracks: "All"), enabled: true),
            ],
            settings: [
                .init(icon: nil, name: "Bifrost Kusama OpenGov", enabled: true),
                .init(icon: nil, name: "Moonriver OpenGov", enabled: true),
                .init(icon: nil, name: "KILT", enabled: true),
                .init(icon: nil, name: "Karura", enabled: true)
            ]
        )

        view?.didReceive(viewModel: mockModels)
    }

    func clear() {}
    func changeSettings(network _: String, isEnabled _: Bool) {}
    func changeSettings(network _: String, new _: Bool) {}
    func changeSettings(network _: String, update _: Bool) {}
    func changeSettings(network _: String, delegate _: Bool) {}
    func selectTracks(network _: String) {}
}

extension GovernanceNotificationsPresenter: GovernanceNotificationsInteractorOutputProtocol {}
