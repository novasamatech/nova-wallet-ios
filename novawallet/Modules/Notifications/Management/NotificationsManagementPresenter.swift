import Foundation
import SoraFoundation

final class NotificationsManagementPresenter {
    weak var view: NotificationsManagementViewProtocol?
    let wireframe: NotificationsManagementWireframeProtocol
    let interactor: NotificationsManagementInteractorInputProtocol
    let viewModelFactory: NotificationsManagemenViewModelFactoryProtocol

    private var notificationStatus: PushNotificationsStatus?

    private var settings: Web3Alert.LocalSettings?
    private var topicsSettings: PushNotification.TopicSettings?
    private var notificationsEnabled: Bool?

    private var modifiedSettings: Web3Alert.LocalSettings?
    private var modifiedNotificationsEnabled: Bool?
    private var modifiedTopicsSettings: PushNotification.TopicSettings?

    private var isSaveAvailable: Bool {
        (settings != modifiedSettings) ||
            (notificationsEnabled != modifiedNotificationsEnabled) ||
            (topicsSettings != modifiedTopicsSettings)
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
        guard
            let settings = modifiedSettings,
            let notificationsEnabled = modifiedNotificationsEnabled ?? notificationsEnabled else {
            return nil
        }
        return .init(
            isNotificationsOn: notificationsEnabled,
            wallets: settings.wallets.count,
            isAnnouncementsOn: isAnnouncementsOn(),
            isSentTokensOn: settings.notifications.tokenSent == .all,
            isReceiveTokensOn: settings.notifications.tokenReceived == .all,
            isGovernanceOn: isGovernanceOn(),
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

    func isGovernanceOn() -> Bool {
        guard let modifiedTopicsSettings = modifiedTopicsSettings else {
            return false
        }

        return modifiedTopicsSettings.topics.contains {
            switch $0 {
            case .chainReferendums, .newChainReferendums:
                return true
            case .appCustom:
                return false
            }
        }
    }

    func isAnnouncementsOn() -> Bool {
        guard let modifiedTopicsSettings = modifiedTopicsSettings else {
            return false
        }

        return modifiedTopicsSettings.topics.contains {
            switch $0 {
            case .chainReferendums, .newChainReferendums:
                return false
            case .appCustom:
                return true
            }
        }
    }

    func checkNotificationsAvailability() {
        if notificationStatus == .denied {
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
                checkNotificationsAvailability()
                updateView()
            } else {
                modifiedNotificationsEnabled = false
                updateView()
            }
        case .announcements:
            modifiedTopicsSettings = modifiedTopicsSettings?.byTogglingAnnouncements()
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
            wireframe.showWallets(
                from: view,

                initState: modifiedSettings?.wallets,
                completion: changeWalletsSettings
            )
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

    func changeGovSettings(settings: [ChainModel.Id: GovernanceNotificationsModel]) {
        var topics: [PushNotification.Topic] = []
        topics = settings.reduce(into: topics) {
            guard $1.value.enabled else {
                return
            }
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

    func getGovSettings() -> GovernanceNotificationsInitModel? {
        var chainReferendumUpdateTopics = [ChainModel.Id: Web3Alert.Selection<Set<TrackIdLocal>>]()
        var chainNewReferendumTopics = [ChainModel.Id: Web3Alert.Selection<Set<TrackIdLocal>>]()
        let allTopics = modifiedTopicsSettings.map(\.topics) ?? []

        for topic in allTopics {
            switch topic {
            case let .chainReferendums(chainId, optTrackId):
                if let trackId = optTrackId {
                    let addedTracks = chainReferendumUpdateTopics[chainId]?.concreteValue ?? []
                    chainReferendumUpdateTopics[chainId] = .concrete(Set(addedTracks + [trackId]))
                } else {
                    chainReferendumUpdateTopics[chainId] = .all
                }
            case let .newChainReferendums(chainId, optTrackId):
                if let trackId = optTrackId {
                    let addedTracks = chainNewReferendumTopics[chainId]?.concreteValue ?? []
                    chainNewReferendumTopics[chainId] = .concrete(Set(addedTracks + [trackId]))
                } else {
                    chainNewReferendumTopics[chainId] = .all
                }
            default: break
            }
        }

        return .init(
            newReferendum: chainNewReferendumTopics,
            referendumUpdate: chainReferendumUpdateTopics
        )
    }

    func changeStakingRewardsSettings(result: Web3Alert.Selection<Set<ChainModel.Id>>?) {
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

    func getStakingRewardsSettings() -> Web3Alert.Selection<Set<ChainModel.Id>>? {
        switch modifiedSettings?.notifications.stakingReward {
        case let .concrete(chains):
            return .concrete(Set(chains))
        case .all:
            return .all
        case .none:
            return nil
        }
    }

    func changeWalletsSettings(wallets: [Web3Alert.LocalWallet]) {
        modifiedSettings = modifiedSettings?.with(wallets: wallets)
        updateView()
    }
}

extension NotificationsManagementPresenter: NotificationsManagementInteractorOutputProtocol {
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
        case .save:
            wireframe.presentRequestStatus(on: view, locale: selectedLocale) { [weak self] in
                self?.save()
            }
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
