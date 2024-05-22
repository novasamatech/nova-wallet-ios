import Foundation
import SoraFoundation

final class CloudBackupSettingsPresenter {
    weak var view: CloudBackupSettingsViewProtocol?
    let wireframe: CloudBackupSettingsWireframeProtocol
    let interactor: CloudBackupSettingsInteractorInputProtocol
    let viewModelFactory: CloudBackupSettingsViewModelFactoryProtocol
    let logger: LoggerProtocol

    private var cloudBackupState: CloudBackupSyncState?

    init(
        interactor: CloudBackupSettingsInteractorInputProtocol,
        wireframe: CloudBackupSettingsWireframeProtocol,
        viewModelFactory: CloudBackupSettingsViewModelFactoryProtocol,
        localizationManager: LocalizationManagerProtocol,
        logger: LoggerProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.viewModelFactory = viewModelFactory
        self.logger = logger

        self.localizationManager = localizationManager
    }

    private func provideViewModel() {
        let viewModel = viewModelFactory.createViewModel(
            with: cloudBackupState,
            locale: selectedLocale
        )

        view?.didReceive(viewModel: viewModel)
    }
}

extension CloudBackupSettingsPresenter: CloudBackupSettingsPresenterProtocol {
    func setup() {
        provideViewModel()

        interactor.setup()
    }

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

extension CloudBackupSettingsPresenter: CloudBackupSettingsInteractorOutputProtocol {
    func didReceive(state: CloudBackupSyncState) {
        logger.debug("New state: \(state)")

        cloudBackupState = state
        provideViewModel()
    }
}

extension CloudBackupSettingsPresenter: Localizable {
    func applyLocalization() {
        if let view, view.isSetup {
            provideViewModel()
        }
    }
}
