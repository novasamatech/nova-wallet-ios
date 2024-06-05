import Foundation
import SoraFoundation

final class CloudBackupSettingsPresenter {
    enum BackupAction {
        case changePassword
        case delete
    }

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

    private func openBackup(actions: [BackupAction]) {
        guard let view else {
            return
        }

        let actionViewModels: [LocalizableResource<ActionManageViewModel>] = actions.map { action in
            switch action {
            case .changePassword:
                return LocalizableResource { locale in
                    ActionManageViewModel(
                        icon: R.image.iconPincode(),
                        title: R.string.localizable.commonChangePassword(preferredLanguages: locale.rLanguages)
                    )
                }
            case .delete:
                return LocalizableResource { locale in
                    ActionManageViewModel(
                        icon: R.image.iconDelete(),
                        title: R.string.localizable.commonDelete(preferredLanguages: locale.rLanguages),
                        isDestructive: true
                    )
                }
            }
        }

        let onAction = ModalPickerClosureContext { [weak self] index in
            guard let self else {
                return
            }

            switch actions[index] {
            case .changePassword:
                wireframe.showChangePassword(from: view)
            case .delete:
                wireframe.showCloudBackupDelete(
                    from: view,
                    reason: .regular,
                    locale: selectedLocale
                ) { [weak self] in
                    self?.interactor.deleteBackup()
                }
            }
        }

        wireframe.presentActionsManage(
            from: view,
            actions: actionViewModels,
            title: LocalizableResource { locale in
                R.string.localizable.commonManageBackup(preferredLanguages: locale.rLanguages)
            },
            delegate: self,
            context: onAction
        )
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
        guard case let .enabled(optSyncResult, _) = cloudBackupState, let syncResult = optSyncResult else {
            return
        }

        switch syncResult {
        case .changes, .issue:
            openBackup(actions: [.delete])
        case .noUpdates:
            openBackup(actions: [.changePassword, .delete])
        }
    }

    func activateSyncIssue() {
        // TODO: Handle updates application separately
        guard
            case let .enabled(optSyncResult, _) = cloudBackupState,
            case let .issue(issue) = optSyncResult else {
            return
        }

        switch issue {
        case .missingOrInvalidPassword:
            wireframe.showEnterPassword(from: view)
        case .remoteDecodingFailed:
            wireframe.showCloudBackupDelete(
                from: view,
                reason: .brokenOrEmpty,
                locale: selectedLocale
            ) { [weak self] in
                self?.interactor.deleteBackup()
            }
        case .remoteReadingFailed, .internalFailure:
            guard let view = view else {
                return
            }

            wireframe.presentNoCloudConnection(from: view, locale: selectedLocale)
        }
    }

    func checkSync() {
        interactor.syncUp()
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
        case .enableBackup, .disableBackup, .deleteBackup:
            interactor.syncUp()

            guard let view else {
                return
            }

            wireframe.presentNoCloudConnection(from: view, locale: selectedLocale)
        }
    }

    func didReceiveConfirmation(changes: CloudBackupSyncResult.Changes) {
        wireframe.showCloudBackupReview(
            from: view,
            changes: changes,
            delegate: self
        )
    }

    func didDeleteBackup() {
        wireframe.presentSuccessNotification(
            R.string.localizable.cloudBackupDeleted(
                preferredLanguages: selectedLocale.rLanguages
            ),
            from: view
        )
    }
}

extension CloudBackupSettingsPresenter: CloudBackupReviewChangesDelegate {
    func cloudBackupReviewerDidApprove(changes: CloudBackupSyncResult.Changes) {
        if case let .updateLocal(updateLocal) = changes, updateLocal.changes.hasWalletRemoves {
            wireframe.showWalletsRemoveConfirmation(on: view, locale: selectedLocale) { [weak self] in
                self?.interactor.approveBackupChanges()
            }
        } else {
            interactor.approveBackupChanges()
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

extension CloudBackupSettingsPresenter: ModalPickerViewControllerDelegate {
    func modalPickerDidSelectModelAtIndex(_ index: Int, context: AnyObject?) {
        guard let onAction = context as? ModalPickerClosureContext else {
            return
        }

        onAction.handler(index)
    }
}
