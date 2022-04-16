import Foundation
import RobinHood

final class DAppAuthSettingsPresenter {
    weak var view: DAppAuthSettingsViewProtocol?
    let wireframe: DAppAuthSettingsWireframeProtocol
    let interactor: DAppAuthSettingsInteractorInputProtocol

    init(
        interactor: DAppAuthSettingsInteractorInputProtocol,
        wireframe: DAppAuthSettingsWireframeProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
    }
}

extension DAppAuthSettingsPresenter: DAppAuthSettingsPresenterProtocol {
    func setup() {}
}

extension DAppAuthSettingsPresenter: DAppAuthSettingsInteractorOutputProtocol {
    func didReceiveDAppList(_ list: DAppList?) {}
    func didReceiveAuthorizationSettings(changes: [DataProviderChange<DAppSettings>]) {}
    func didReceive(error: Error) {}
}
