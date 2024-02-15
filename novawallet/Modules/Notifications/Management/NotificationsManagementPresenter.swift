import Foundation
import SoraFoundation

final class NotificationsManagementPresenter {
    weak var view: NotificationsManagementViewProtocol?
    let wireframe: NotificationsManagementWireframeProtocol
    let interactor: NotificationsManagementInteractorInputProtocol
    let viewModelFactory: NotificationsManagemenViewModelFactoryProtocol

    private var settings: LocalPushSettings?
    private var notificationsEnabled: Bool?
    private var announcementsEnabled: Bool?

    @Atomic(defaultValue: nil)
    private var modifiedSettings: LocalPushSettings?
    @Atomic(defaultValue: nil)
    private var modifiedAnnouncementsEnabled: Bool?
    @Atomic(defaultValue: nil)
    private var modifiedNotificationsEnabled: Bool?

    private var isSaveAvailable: Bool {
        guard let settings = settings,
              let announcementsEnabled = announcementsEnabled,
              let notificationsEnabled = notificationsEnabled else {
            return false
        }

        let parametersWasModified = settings != modifiedSettings ||
            announcementsEnabled != modifiedAnnouncementsEnabled ||
            notificationsEnabled != modifiedNotificationsEnabled

        return parametersWasModified
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

    private func getParameters() -> NotificationsManagementParameters? {
        guard let settings = modifiedSettings,
              let notificationsEnabled = modifiedNotificationsEnabled,
              let announcementsEnabled = modifiedAnnouncementsEnabled else {
            return nil
        }
        return .init(
            isNotificationsOn: notificationsEnabled,
            wallets: settings.wallets.count,
            isAnnouncementsOn: announcementsEnabled,
            isSentTokensOn: settings.notifications.tokenSent,
            isReceiveTokensOn: settings.notifications.tokenReceived,
            isGovernanceOn: settings.notifications.govMyDelegatorVoted.notificationsEnabled,
            isStakingOn: settings.notifications.stakingReward.notificationsEnabled
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
}

extension NotificationsManagementPresenter: NotificationsManagementPresenterProtocol {
    func setup() {
        interactor.setup()
        updateView()
    }

    func viewWillAppear() {
        interactor.checkNotificationsStatus()
    }

    func actionRow(_ row: NotificationsManagementRow) {
        switch row {
        case .enableNotifications:
            guard modifiedNotificationsEnabled != nil else {
                return
            }
            if modifiedNotificationsEnabled == false {
                interactor.enableNotifications()
                modifiedNotificationsEnabled = true
                updateView()
            } else {
                modifiedNotificationsEnabled = false
                updateView()
            }
        case .announcements:
            modifiedAnnouncementsEnabled?.toggle()
            updateView()
        case .sentTokens:
            modifiedSettings = modifiedSettings?.with {
                $0.tokenSent.toggle()
            }
            updateView()
        case .receivedTokens:
            modifiedSettings = modifiedSettings?.with {
                $0.tokenReceived.toggle()
            }
            updateView()
        case .wallets:
            wireframe.showWallets(from: view)
        case .gov:
            wireframe.showGovSetup(from: view)
        case .staking:
            wireframe.showStakingRewardsSetup(from: view)
        }
    }

    func save() {
        guard let settings = modifiedSettings,
              let notificationsEnabled = modifiedNotificationsEnabled,
              let modifiedAnnouncementsEnabled = modifiedAnnouncementsEnabled else {
            return
        }
        view?.startLoading()
        interactor.save(
            settings: settings,
            notificationsEnabled: notificationsEnabled,
            announcementsEnabled: modifiedAnnouncementsEnabled
        )
    }
}

extension NotificationsManagementPresenter: NotificationsManagementInteractorOutputProtocol {
    func didReceive(settings: LocalPushSettings) {
        self.settings = settings
        if modifiedSettings == nil {
            modifiedSettings = settings
        }
        updateView()
    }

    func didReceive(notificationsEnabled: Bool) {
        if notificationsEnabled == nil {
            self.notificationsEnabled = notificationsEnabled
        }
        modifiedNotificationsEnabled = notificationsEnabled
        updateView()
    }

    func didReceive(announcementsEnabled: Bool) {
        self.announcementsEnabled = announcementsEnabled
        if modifiedAnnouncementsEnabled == nil {
            modifiedAnnouncementsEnabled = announcementsEnabled
        }
        updateView()
    }

    func didReceive(error: NotificationsManagementError) {
        switch error {
        case let .settingsSubscription(error):
            wireframe.presentRequestStatus(on: view, locale: selectedLocale) { [weak self] in
                self?.interactor.remakeSubscription()
            }
        case .notificationsDisabledInSettings:
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
        }
    }

    func didReceiveSaveCompletion() {
        view?.stopLoading()
        wireframe.complete(from: view)
    }
}

extension NotificationsManagementPresenter: Localizable {
    func applyLocalization() {
        if view?.isSetup == true {
            updateView()
        }
    }
}
