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

    func toggleICloudBackup() {
        guard let cloudBackupState else {
            return
        }

        switch cloudBackupState {
        case .disabled:
            self.cloudBackupState = nil

            interactor.enableBackup()
        case .unavailable, .enabled:
            self.cloudBackupState = .disabled(lastSyncDate: nil)

            interactor.disableBackup()
        }

        provideViewModel()
    }

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

    func didReceive(error: CloudBackupSettingsInteractorError) {
        logger.error("Error: \(error)")

        switch error {
        case .enableBackup, .disableBackup:
            interactor.retryStateFetch()

            guard let view else {
                return
            }

            wireframe.presentNoCloudConnection(from: view, locale: selectedLocale)
        }
    }
}

extension CloudBackupSettingsPresenter: Localizable {
    func applyLocalization() {
        if let view, view.isSetup {
            provideViewModel()
        }
    }
}
