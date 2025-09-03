import Foundation
import Foundation_iOS

final class NotificationsManagementPresenter {
    weak var view: NotificationsManagementViewProtocol?
    let wireframe: NotificationsManagementWireframeProtocol
    let interactor: NotificationsManagementInteractorInputProtocol
    let viewModelFactory: NotificationsManagemenViewModelFactoryProtocol

    private var allWallets: [MetaAccountModel.Id: MetaAccountModel]?
    private var notificationStatus: PushNotificationsStatus?

    private var settings: Web3Alert.LocalSettings?
    private var topicsSettings: PushNotification.TopicSettings?
    private var notificationsEnabled: Bool?

    private var modifiedSettings: Web3Alert.LocalSettings?
    private var modifiedNotificationsEnabled: Bool?
    private var modifiedTopicsSettings: PushNotification.TopicSettings?

    private var isSaveAvailable: Bool {
        let settingsWasModified = (settings != modifiedSettings) ||
            (notificationsEnabled != modifiedNotificationsEnabled) ||
            (topicsSettings != modifiedTopicsSettings)
        let isAmbiguousState = areAllNotificationsOff() == true && modifiedNotificationsEnabled == true
        return settingsWasModified && !isAmbiguousState
    }

    init(
        interactor: NotificationsManagementInteractorInputProtocol,
        wireframe: NotificationsManagementWireframeProtocol,
        viewModelFactory: NotificationsManagemenViewModelFactoryProtocol,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.viewModelFactory = viewModelFactory
        self.localizationManager = localizationManager
    }

    func changeWalletsSettings(wallets: [Web3Alert.LocalWallet]) {
        guard let allWallets else { return }

        let selectedMultisigs = wallets
            .compactMap { allWallets[$0.metaId] }
            .filter { $0.type == .multisig }

        modifiedSettings = modifiedSettings?.with(wallets: wallets)

        if selectedMultisigs.isEmpty {
            modifiedSettings = modifiedSettings?.with {
                $0.newMultisig = nil
                $0.multisigApproval = nil
                $0.multisigExecuted = nil
                $0.multisigCancelled = nil
            }
        } else if modifiedSettings?.notifications.isMultisigOn == false {
            modifiedSettings = modifiedSettings?.with {
                $0.newMultisig = .all
                $0.multisigApproval = .all
                $0.multisigExecuted = .all
                $0.multisigCancelled = .all
            }
        }

        updateView()
    }
}

// MARK: - Private

private extension NotificationsManagementPresenter {
    func getParameters() -> NotificationsManagementParameters? {
        guard
            let settings = modifiedSettings,
            let topicSettings = modifiedTopicsSettings,
            let notificationsEnabled = modifiedNotificationsEnabled ?? notificationsEnabled else {
            return nil
        }
        return .init(
            isNotificationsOn: notificationsEnabled,
            wallets: settings.wallets.count,
            isAnnouncementsOn: topicSettings.isAnnouncementsOn,
            isSentTokensOn: settings.notifications.tokenSent == .all,
            isReceiveTokensOn: settings.notifications.tokenReceived == .all,
            isMultisigTransactionsOn: settings.notifications.isMultisigOn,
            isGovernanceOn: topicSettings.isGovernanceOn,
            isStakingOn: settings.notifications.stakingReward?.notificationsEnabled ?? false
        )
    }

    func updateView() {
        guard let parameters = getParameters() else {
            return
        }
        let viewModel = viewModelFactory.createSectionViewModels(
            parameters: parameters,
            locale: selectedLocale
        )
        view?.didReceive(sections: viewModel)

        view?.didReceive(isSaveActionAvailabe: isSaveAvailable)
    }

    func areAllNotificationsOff() -> Bool? {
        guard let parameters = getParameters() else {
            return nil
        }
        return !parameters.isAnnouncementsOn &&
            !parameters.isGovernanceOn &&
            !parameters.isReceiveTokensOn &&
            !parameters.isSentTokensOn &&
            !parameters.isStakingOn
    }

    func checkNotificationsAvailability() {
        if notificationStatus == .denied {
            showNotificationDeniedError()
        }
    }

    func showNotificationDeniedError() {
        let message = R.string.localizable.notificationsErrorDisabledInSettingsMessage(
            preferredLanguages: selectedLocale.rLanguages
        )
        let title = R.string.localizable.notificationsErrorDisabledInSettingsTitle(
            preferredLanguages: selectedLocale.rLanguages
        )
        wireframe.askOpenApplicationSettings(
            with: message,
            title: title,
            from: view,
            locale: selectedLocale
        )
        modifiedNotificationsEnabled = false
        updateView()
    }

    func disableNotificationIfNeeded() {
        if areAllNotificationsOff() == true {
            modifiedNotificationsEnabled = false
        }
    }

    func isStatusDeniedError(_ error: Error) -> Bool {
        if case let PushNotificationsServiceFacadeError.settingsUpdateFailed(internalError) = error,
           (internalError as? PushNotificationsStatusServiceError) == .notifcationTokensWaitDenied {
            return true
        }

        return false
    }

    func changeGovSettings(settings: GovernanceNotificationsModel) {
        let currentSettings = modifiedTopicsSettings ?? .init(topics: [])
        modifiedTopicsSettings = currentSettings.applying(governanceSettings: settings)
        disableNotificationIfNeeded()
        updateView()
    }

    func changeStakingRewardsSettings(result: Web3Alert.Selection<Set<Web3Alert.LocalChainId>>?) {
        modifiedSettings = modifiedSettings?.with {
            switch result {
            case .all:
                $0.stakingReward = .all
            case let .concrete(selectedChains):
                $0.stakingReward = !selectedChains.isEmpty ? .concrete(selectedChains) : nil
            case nil:
                $0.stakingReward = nil
            }
        }

        disableNotificationIfNeeded()
        updateView()
    }

    func changeMultisigSettings(result: MultisigNotificationsModel) {
        modifiedSettings = modifiedSettings?.with {
            $0.newMultisig = result.signatureRequested ? .all : nil
            $0.multisigApproval = result.signedBySignatory ? .all : nil
            $0.multisigExecuted = result.transactionExecuted ? .all : nil
            $0.multisigCancelled = result.transactionRejected ? .all : nil
        }

        disableNotificationIfNeeded()
        updateView()
    }
}

// MARK: - NotificationsManagementPresenterProtocol

extension NotificationsManagementPresenter: NotificationsManagementPresenterProtocol {
    func setup() {
        interactor.setup()
        updateView()
    }

    func actionRow(_ row: NotificationsManagementRow) {
        switch row {
        case .enableNotifications:
            guard modifiedNotificationsEnabled != nil else {
                return
            }
            if modifiedNotificationsEnabled == false {
                modifiedNotificationsEnabled = true
                checkNotificationsAvailability()
                updateView()
            } else {
                modifiedNotificationsEnabled = false
                updateView()
            }
        case .announcements:
            modifiedTopicsSettings = modifiedTopicsSettings?.byTogglingAnnouncements()
            disableNotificationIfNeeded()
            updateView()
        case .sentTokens:
            modifiedSettings = modifiedSettings?.with {
                $0.tokenSent.toggle()
            }
            disableNotificationIfNeeded()
            updateView()
        case .receivedTokens:
            modifiedSettings = modifiedSettings?.with {
                $0.tokenReceived.toggle()
            }
            disableNotificationIfNeeded()
            updateView()
        case .wallets:
            wireframe.showWallets(
                from: view,
                initState: modifiedSettings?.wallets,
                completion: changeWalletsSettings
            )
        case .gov:
            let settings = modifiedTopicsSettings.map { GovernanceNotificationsModel(topicSettings: $0) }
            wireframe.showGovSetup(
                from: view,
                settings: settings ?? .empty(),
                completion: changeGovSettings
            )
        case .staking:
            wireframe.showStakingRewardsSetup(
                from: view,
                selectedChains: modifiedSettings?.notifications.stakingReward,
                completion: changeStakingRewardsSettings
            )
        case .multisig:
            let settings = MultisigNotificationsModel(from: modifiedSettings)
            let selectedMetaIds = Set(modifiedSettings?.wallets.map(\.metaId) ?? [])

            wireframe.showMultisigSetup(
                from: view,
                settings: settings,
                selectedMetaIds: selectedMetaIds,
                completion: changeMultisigSettings
            )
        }
    }

    func save() {
        guard
            let settings = modifiedSettings,
            let notificationsEnabled = modifiedNotificationsEnabled else {
            return
        }

        view?.startLoading()
        let topics = modifiedTopicsSettings ?? .init(topics: [])
        interactor.save(
            settings: settings,
            topics: topics,
            notificationsEnabled: notificationsEnabled
        )
    }

    func back() {
        guard isSaveAvailable else {
            wireframe.complete(from: view)
            return
        }

        let languages = selectedLocale.rLanguages

        let closeViewModel = AlertPresentableAction(
            title: R.string(preferredLanguages: languages).localizable.commonClose(),
            style: .destructive
        ) { [weak self] in
            self?.wireframe.complete(from: self?.view)
        }

        let viewModel = AlertPresentableViewModel(
            title: nil,
            message: R.string(preferredLanguages: languages).localizable.commonCloseWhenChangesConfirmation(),
            actions: [closeViewModel],
            closeAction: R.string(preferredLanguages: languages).localizable.commonCancel()
        )

        wireframe.present(viewModel: viewModel, style: .actionSheet, from: view)
    }
}

// MARK: - NotificationsManagementInteractorOutputProtocol

extension NotificationsManagementPresenter: NotificationsManagementInteractorOutputProtocol {
    func didReceive(wallets: [MetaAccountModel]) {
        allWallets = wallets.reduceToDict()
    }

    func didReceive(settings: Web3Alert.LocalSettings) {
        self.settings = settings
        if modifiedSettings == nil {
            modifiedSettings = settings
        } else {
            modifiedSettings = modifiedSettings?.updatingMetadata(from: settings)
        }

        updateView()
    }

    func didReceive(topicsSettings: PushNotification.TopicSettings) {
        self.topicsSettings = topicsSettings
        if modifiedTopicsSettings == nil {
            modifiedTopicsSettings = topicsSettings
        }
        updateView()
    }

    func didReceive(notificationStatus: PushNotificationsStatus) {
        self.notificationStatus = notificationStatus
        notificationsEnabled = notificationStatus == .active

        if modifiedNotificationsEnabled == nil {
            modifiedNotificationsEnabled = notificationsEnabled
        }

        updateView()
    }

    func didReceive(error: NotificationsManagementError) {
        switch error {
        case .settingsSubscription:
            wireframe.presentRequestStatus(on: view, locale: selectedLocale) { [weak self] in
                self?.interactor.remakeSubscription()
            }
        case let .save(error):
            view?.stopLoading()
            if isStatusDeniedError(error) {
                showNotificationDeniedError()
            } else {
                let title = R.string(preferredLanguages: selectedLocale.rLanguages).localizable.commonErrorGeneralTitle()

                let message = error.localizedDescription

                wireframe.presentRequestStatus(
                    on: view,
                    title: title,
                    message: message,
                    locale: selectedLocale,
                    retryAction: { [weak self] in
                        self?.save()
                    }
                )
            }
        }
    }

    func didReceiveSaveCompletion() {
        view?.stopLoading()
        wireframe.saved(on: view)
    }
}

// MARK: - Localizable

extension NotificationsManagementPresenter: Localizable {
    func applyLocalization() {
        if view?.isSetup == true {
            updateView()
        }
    }
}
