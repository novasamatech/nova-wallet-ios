import Foundation
import SoraFoundation

final class NotificationsManagementPresenter {
    weak var view: NotificationsManagementViewProtocol?
    let wireframe: NotificationsManagementWireframeProtocol
    let interactor: NotificationsManagementInteractorInputProtocol
    let viewModelFactory: NotificationsManagemenViewModelFactoryProtocol

    weak var delegate: PushNotificationsStatusDelegate?
    private var settings: LocalPushSettings?
    private var topicsSettings: LocalNotificationTopicSettings?
    private var notificationsEnabled: Bool?
    private var announcementsEnabled: Bool?

    private var modifiedSettings: LocalPushSettings?
    private var modifiedAnnouncementsEnabled: Bool?
    private var modifiedNotificationsEnabled: Bool?
    private var modifiedTopicsSettings: LocalNotificationTopicSettings?

    private var isSaveAvailable: Bool {
        guard let settings = settings,
              let announcementsEnabled = announcementsEnabled,
              let notificationsEnabled = notificationsEnabled else {
            return false
        }

        let parametersWasModified = settings != modifiedSettings ||
            announcementsEnabled != modifiedAnnouncementsEnabled ||
            notificationsEnabled != modifiedNotificationsEnabled ||
            topicsSettings != modifiedTopicsSettings

        return parametersWasModified
    }

    init(
        interactor: NotificationsManagementInteractorInputProtocol,
        wireframe: NotificationsManagementWireframeProtocol,
        viewModelFactory: NotificationsManagemenViewModelFactoryProtocol,
        localizationManager: LocalizationManagerProtocol,
        delegate: PushNotificationsStatusDelegate?
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.viewModelFactory = viewModelFactory
        self.delegate = delegate
        self.localizationManager = localizationManager
    }

    private func getParameters() -> NotificationsManagementParameters? {
        guard let settings = modifiedSettings,
              let notificationsEnabled = modifiedNotificationsEnabled ?? notificationsEnabled,
              let announcementsEnabled = modifiedAnnouncementsEnabled ?? announcementsEnabled else {
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

    func actionRow(_ row: NotificationsManagementRow) {
        switch row {
        case .enableNotifications:
            guard modifiedNotificationsEnabled != nil else {
                return
            }
            if modifiedNotificationsEnabled == false {
                modifiedNotificationsEnabled = true
                interactor.enableNotifications()
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
            wireframe.showGovSetup(
                from: view,
                settings: getGovSettings(),
                completion: changeGovSettings
            )
        case .staking:
            wireframe.showStakingRewardsSetup(
                from: view,
                selectedChains: getStakingRewardsSettings(),
                completion: changeStakingRewardsSettings
            )
        }
    }

    func save() {
        guard let settings = modifiedSettings,
              let notificationsEnabled = modifiedNotificationsEnabled,
              let modifiedAnnouncementsEnabled = modifiedAnnouncementsEnabled else {
            return
        }

        view?.startLoading()
        let topics = modifiedTopicsSettings ?? .init(topics: [])
        interactor.save(
            settings: settings,
            topics: topics,
            notificationsEnabled: notificationsEnabled,
            announcementsEnabled: modifiedAnnouncementsEnabled
        )
    }

    func changeGovSettings(settings: [ChainModel.Id: GovernanceNotificationsModel]) {
        var topics: [NotificationTopic] = []
        topics = settings.reduce(into: topics) {
            switch $1.value.tracks {
            case .all:
                if $1.value.newReferendum {
                    $0.append(.newChainReferendums(chainId: $1.key, trackId: nil))
                }
                if $1.value.referendumUpdate {
                    $0.append(.chainReferendums(chainId: $1.key, trackId: nil))
                }
            case let .concrete(trackIds, _):
                for trackId in trackIds {
                    if $1.value.newReferendum {
                        $0.append(.newChainReferendums(chainId: $1.key, trackId: trackId))
                    }
                    if $1.value.referendumUpdate {
                        $0.append(.chainReferendums(chainId: $1.key, trackId: trackId))
                    }
                }
            }
        }
        modifiedTopicsSettings = .init(topics: topics)
        updateView()
    }

    func getGovSettings() -> [ChainModel.Id: GovernanceNotificationsModel] {
        [:]
    }

    func changeStakingRewardsSettings(result: Selection<Set<ChainModel.Id>>?) {
        modifiedSettings = modifiedSettings?.with {
            switch result {
            case .all:
                $0.stakingReward = .all
            case let .concrete(selectedChains):
                $0.stakingReward = .concrete(Array(selectedChains))
            case nil:
                $0.stakingReward = .concrete(Array([]))
            }
        }

        updateView()
    }

    func getStakingRewardsSettings() -> Selection<Set<ChainModel.Id>>? {
        switch modifiedSettings?.notifications.stakingReward {
        case let .concrete(chains):
            return .concrete(Set(chains))
        case .all:
            return .all
        default:
            return nil
        }
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

    func didReceive(topicsSettings: LocalNotificationTopicSettings) {
        self.topicsSettings = topicsSettings
        if modifiedTopicsSettings == nil {
            modifiedTopicsSettings = topicsSettings
        }
        updateView()
    }

    func didReceive(notificationsEnabled: Bool) {
        self.notificationsEnabled = notificationsEnabled
        if modifiedNotificationsEnabled == nil {
            modifiedNotificationsEnabled = notificationsEnabled
        }
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
        case .settingsSubscription:
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
            modifiedNotificationsEnabled = false
            updateView()
        }
    }

    func didReceiveSaveCompletion() {
        view?.stopLoading()
        delegate?.pushNotificationsStatusDidUpdate()
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
