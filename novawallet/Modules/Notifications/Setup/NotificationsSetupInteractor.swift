import UIKit
import SoraKeystore

final class NotificationsSetupInteractor {
    weak var presenter: NotificationsSetupInteractorOutputProtocol?

    let servicesFactory: Web3AlertsServicesFactoryProtocol
    let chainRegistry: ChainRegistryProtocol
    let settingsMananger: SettingsManagerProtocol

    private var syncService: Web3AlertsSyncServiceProtocol?
    private var pushNotificationsService: PushNotificationsServiceProtocol?

    let selectedWallet: MetaAccountModel
    private var chains: [ChainModel.Id: ChainModel] = [:]

    init(
        servicesFactory: Web3AlertsServicesFactoryProtocol,
        selectedWallet: MetaAccountModel,
        chainRegistry: ChainRegistryProtocol,
        settingsMananger: SettingsManagerProtocol
    ) {
        self.servicesFactory = servicesFactory
        self.selectedWallet = selectedWallet
        self.chainRegistry = chainRegistry
        self.settingsMananger = settingsMananger
    }

    private func registerPushNotifications() {
        guard let pushNotificationsService = pushNotificationsService else {
            return
        }
        pushNotificationsService.register { [weak self] status in
            DispatchQueue.main.async {
                self?.presenter?.didRegister(notificationStatus: status)
            }
        }
    }

    private func saveSettingsAndRegisterDevice() {
        guard let syncService = syncService else {
            return
        }
        let chainFormat = ChainFormat.substrate(UInt16(SNAddressType.polkadotMain.rawValue))
        let chainSpecific = selectedWallet.chainAccounts.reduce(into: [Web3AlertWallet.ChainId: AccountAddress]()) {
            if let chainFormat = chains[$1.chainId]?.chainFormat {
                let address = try? $1.accountId.toAddress(using: chainFormat)
                $0[$1.chainId] = address ?? ""
            }
        }
        let web3Wallet = Web3AlertWallet(
            baseSubstrate: try? selectedWallet.substrateAccountId?.toAddress(using: chainFormat),
            baseEthereum: try? selectedWallet.ethereumAddress?.toAddress(using: .ethereum),
            chainSpecific: chainSpecific
        )
        let remoteIdentifier = UUID().uuidString
        let settings = LocalPushSettings(
            remoteIdentifier: remoteIdentifier,
            pushToken: "",
            updatedAt: Date(),
            wallets: [web3Wallet],
            notifications: .init(
                stakingReward: nil,
                transfer: nil,
                tokenSent: true,
                tokenReceived: true
            )
        )

        syncService.save(
            settings: settings,
            runningInQueue: .main
        ) { [weak self] in
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
