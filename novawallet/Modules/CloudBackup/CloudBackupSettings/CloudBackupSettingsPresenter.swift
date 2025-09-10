import Foundation
import Foundation_iOS

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

    private var isActive: Bool = false
    private var waitingBackupEnable = false

    private var cloudBackupState: CloudBackupSyncState?
    private var cloudBackupSyncMonitorStatus: CloudBackupSyncMonitorStatus?

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
            syncMonitorStatus: cloudBackupSyncMonitorStatus,
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
                        title: R.string(preferredLanguages: locale.rLanguages).localizable.commonChangePassword()
                    )
                }
            case .delete:
                return LocalizableResource { locale in
                    ActionManageViewModel(
                        icon: R.image.iconDelete(),
                        title: R.string(preferredLanguages: locale.rLanguages).localizable.commonDeleteBackup(),
                        style: .destructive
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
                R.string(preferredLanguages: locale.rLanguages).localizable.commonManageBackup()
            },
            delegate: self,
            context: onAction
        )
    }

    private func showBackupIssueAfterSync(_ issue: CloudBackupSyncResult.Issue, waitingBackupEnable: Bool) {
        switch issue {
        case .missingPassword:
            if waitingBackupEnable {
                wireframe.showEnterPassword(from: view)
            }
        case .invalidPassword:
            wireframe.showPasswordChangedConfirmation(
                on: view,
                locale: selectedLocale
            ) { [weak self] in
                self?.wireframe.showEnterPassword(from: self?.view)
            }
        case .newBackupCreationNeeded:
            if waitingBackupEnable {
                wireframe.showBackupCreation(from: view)
            }
        case .remoteDecodingFailed, .remoteEmpty:
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

    private func showBackupStateSyncResultAfterSync(
        _ cloudBackupSyncResult: CloudBackupSyncResult,
        waitingBackupEnable: Bool
    ) {
        switch cloudBackupSyncResult {
        case let .changes(changes):
            guard changes.isDestructive else {
                logger.debug("No destructive changes found")
                return
            }

            wireframe.showReviewUpdatesConfirmation(
                on: view,
                locale: selectedLocale
            ) { [weak self] in
                guard let self else {
                    return
                }

                self.wireframe.showCloudBackupReview(
                    from: view,
                    changes: changes,
                    delegate: self
                )
            }
        case let .issue(issue):
            showBackupIssueAfterSync(issue, waitingBackupEnable: waitingBackupEnable)
        case .noUpdates:
            logger.debug("No updates after sync")
        }
    }

    private func showBackupStateAfterSync(for waitingBackupEnable: Bool) {
        switch cloudBackupState {
        case .unavailable:
            guard let view else {
                return
            }

            wireframe.presentCloudBackupUnavailable(from: view, locale: selectedLocale)
        case let .enabled(cloudBackupSyncResult, _):
            guard let syncResult = cloudBackupSyncResult else {
                return
            }

            showBackupStateSyncResultAfterSync(syncResult, waitingBackupEnable: waitingBackupEnable)
        case .disabled, .none:
            break
        }
    }

    private func handleSync(issue: CloudBackupSyncResult.Issue) {
        switch issue {
        case .missingPassword, .invalidPassword:
            wireframe.showEnterPassword(from: view)
        case .remoteDecodingFailed, .remoteEmpty:
            wireframe.showCloudBackupDelete(
                from: view,
                reason: .brokenOrEmpty,
                locale: selectedLocale
            ) { [weak self] in
                self?.interactor.deleteBackup()
            }
        case .newBackupCreationNeeded:
            wireframe.showBackupCreation(from: view)
        case .remoteReadingFailed, .internalFailure:
            guard let view = view else {
                return
            }

            wireframe.presentNoCloudConnection(from: view, locale: selectedLocale)
        }
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

            waitingBackupEnable = true

            interactor.enableBackup()
        case .unavailable, .enabled:
            self.cloudBackupState = .disabled(lastSyncDate: nil)

            interactor.disableBackup()
        }

        provideViewModel()
    }

    func activateManualBackup() {
        interactor.fetchNumberOfWalletsWithSecrets()
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
        if case .unavailable = cloudBackupState, let view = view {
            wireframe.presentCloudBackupUnavailable(from: view, locale: selectedLocale)
            return
        }

        guard case let .enabled(optSyncResult, _) = cloudBackupState else {
            return
        }

        switch optSyncResult {
        case let .changes(changes):
            guard changes.isDestructive else {
                return
            }

            wireframe.showCloudBackupReview(
                from: view,
                changes: changes,
                delegate: self
            )
        case let .issue(issue):
            handleSync(issue: issue)
        case .noUpdates, .none:
            break
        }
    }

    func becomeActive() {
        isActive = true

        interactor.becomeActive()
    }

    func becomeInactive() {
        isActive = false

        interactor.becomeInactive()
    }
}

extension CloudBackupSettingsPresenter: CloudBackupSettingsInteractorOutputProtocol {
    func didReceive(state: CloudBackupSyncState) {
        logger.debug("New state: \(state)")

        cloudBackupState = state
        provideViewModel()

        if isActive {
            showBackupStateAfterSync(for: waitingBackupEnable)
        }

        if !state.isSyncing {
            waitingBackupEnable = false
        }
    }

    func didReceive(error: CloudBackupSettingsInteractorError) {
        logger.error("Error: \(error)")

        switch error {
        case .deleteBackup:
            interactor.syncUp()

            guard let view else {
                return
            }

            wireframe.presentNoCloudConnection(from: view, locale: selectedLocale)
        case .secretsCounter:
            _ = wireframe.present(
                error: CommonError.databaseSubscription,
                from: view,
                locale: selectedLocale
            )
        }
    }

    func didDeleteBackup() {
        wireframe.presentMultilineSuccessNotification(
            R.string(preferredLanguages: selectedLocale.rLanguages).localizable.cloudBackupDeleted(),
            from: view
        )
    }

    func didReceive(numberOfWalletsWithSecrets: Int) {
        if numberOfWalletsWithSecrets > 0 {
            wireframe.showManualBackup(from: view)
        } else {
            wireframe.present(
                message: R.string(preferredLanguages: selectedLocale.rLanguages).localizable.noManualBackupAlertMessage(),
                title: R.string(preferredLanguages: selectedLocale.rLanguages).localizable.noManualBackupAlertTitle(),
                closeAction: R.string(preferredLanguages: selectedLocale.rLanguages).localizable.commonClose(),
                from: view
            )
        }
    }

    func didReceive(syncMonitorStatus: CloudBackupSyncMonitorStatus?) {
        logger.debug("Sync monitor: \(String(describing: syncMonitorStatus))")

        cloudBackupSyncMonitorStatus = syncMonitorStatus

        provideViewModel()
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
