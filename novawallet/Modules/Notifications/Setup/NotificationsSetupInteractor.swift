import UIKit
import SoraKeystore

final class NotificationsSetupInteractor {
    weak var presenter: NotificationsSetupInteractorOutputProtocol?

    let chainRegistry: ChainRegistryProtocol
    let localPushSettingsFactory: LocalPushSettingsFactoryProtocol
    let pushNotificationsFacade: PushNotificationsServiceFacadeProtocol

    let selectedWallet: MetaAccountModel
    private var chains: [ChainModel.Id: ChainModel] = [:]

    init(
        selectedWallet: MetaAccountModel,
        chainRegistry: ChainRegistryProtocol,
        pushNotificationsFacade: PushNotificationsServiceFacadeProtocol,
        localPushSettingsFactory: LocalPushSettingsFactoryProtocol
    ) {
        self.selectedWallet = selectedWallet
        self.chainRegistry = chainRegistry
        self.pushNotificationsFacade = pushNotificationsFacade
        self.localPushSettingsFactory = localPushSettingsFactory
    }

    private func subscribePushNotifications() {
        pushNotificationsFacade.subscribeStatus(self) { [weak self] _, newStatus in
            if PushNotificationsStatus.userInitiatedStatuses.contains(newStatus) {
                self?.presenter?.didRegister(notificationStatus: newStatus)
            }
        }
    }

    private func saveSettingsAndRegisterDevice() {
        let accountBasedSettings = localPushSettingsFactory.createSettings(
            for: selectedWallet,
            chains: chains
        )

        // TODO: Fix topics settings default
        let topicsSettings = PushNotification.TopicSettings(topics: [])

        let allSettings = PushNotification.AllSettings(
            notificationsEnabled: true,
            accountBased: accountBasedSettings,
            topics: topicsSettings
        )

        pushNotificationsFacade.save(
            settings: allSettings
        ) { [weak self] result in
            switch result {
            case .success:
                self?.subscribePushNotifications()
            case let .failure(error):
                self?.presenter?.didReceive(error: error)
            }
        }
    }

    private func subscribeChains() {
        // TODO: We need to wait those chains before notifications enabled
        chainRegistry.chainsSubscribe(
            self,
            runningInQueue: .main
        ) { [weak self] changes in
            guard let self = self else {
                return
            }
            self.chains = changes.mergeToDict(self.chains)
        }
    }
}

extension NotificationsSetupInteractor: NotificationsSetupInteractorInputProtocol {
    func setup() {
        subscribeChains()
    }

    func enablePushNotifications() {
        saveSettingsAndRegisterDevice()
    }
}
