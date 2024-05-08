import Foundation

final class CloudBackupSettingsPresenter {
    weak var view: CloudBackupSettingsViewProtocol?
    let wireframe: CloudBackupSettingsWireframeProtocol
    let interactor: CloudBackupSettingsInteractorInputProtocol

    init(
        interactor: CloudBackupSettingsInteractorInputProtocol,
        wireframe: CloudBackupSettingsWireframeProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
    }
}

extension CloudBackupSettingsPresenter: CloudBackupSettingsPresenterProtocol {
    func setup() {}

    func toggleICloudBackup() {}

    func activateManualBackup() {
        wireframe.showManualBackup(from: view)
    }

    func activateSyncAction() {
        // TODO: Implement in separate task
    }

    func activateSyncIssue() {
        // TODO: Implement in separate task
    }
}

extension CloudBackupSettingsPresenter: CloudBackupSettingsInteractorOutputProtocol {}
