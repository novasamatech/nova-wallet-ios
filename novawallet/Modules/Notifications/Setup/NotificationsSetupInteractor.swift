import UIKit
import SoraKeystore

final class NotificationsSetupInteractor {
    weak var presenter: NotificationsSetupInteractorOutputProtocol?

    let servicesFactory: Web3AlertsServicesFactoryProtocol
    let chainRegistry: ChainRegistryProtocol
    let settingsMananger: SettingsManagerProtocol
    let localPushSettingsFactory: LocalPushSettingsFactoryProtocol

    private var syncService: Web3AlertsSyncServiceProtocol?
    private var pushNotificationsService: PushNotificationsServiceProtocol?

    let selectedWallet: MetaAccountModel
    private var chains: [ChainModel.Id: ChainModel] = [:]

    init(
        servicesFactory: Web3AlertsServicesFactoryProtocol,
        selectedWallet: MetaAccountModel,
        chainRegistry: ChainRegistryProtocol,
        settingsMananger: SettingsManagerProtocol,
        localPushSettingsFactory: LocalPushSettingsFactoryProtocol
    ) {
        self.servicesFactory = servicesFactory
        self.selectedWallet = selectedWallet
        self.chainRegistry = chainRegistry
        self.settingsMananger = settingsMananger
        self.localPushSettingsFactory = localPushSettingsFactory
    }

    private func registerPushNotifications() {
        guard let pushNotificationsService = pushNotificationsService else {
            return
        }
        pushNotificationsService.register(completionQueue: .main) { [weak self] status in
            self?.presenter?.didRegister(notificationStatus: status)
        }
    }

    private func saveSettingsAndRegisterDevice() {
        guard let syncService = syncService else {
            return
        }

        let settings = localPushSettingsFactory.createSettings(
            for: selectedWallet,
            chains: chains
        )

        syncService.save(
            settings: settings,
            runningInQueue: .main
        ) { [weak self] error in
            if let error = error {
                self?.presenter?.didReceive(error: error)
                return
            }
            self?.settingsMananger.notificationsEnabled = true
            self?.registerPushNotifications()
        }
    }

    private func subscribeChains() {
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
        syncService = servicesFactory.createSyncService()
        pushNotificationsService = servicesFactory.createPushNotificationsService()
        saveSettingsAndRegisterDevice()
    }
}
