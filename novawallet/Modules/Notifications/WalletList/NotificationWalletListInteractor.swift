import UIKit
import Operation_iOS

final class NotificationWalletListInteractor: AnyProviderAutoCleaning {
    weak var presenter: NotificationWalletListInteractorOutputProtocol?
    let chainRegistry: ChainRegistryProtocol
    let settingsLocalSubscriptionFactory: SettingsLocalSubscriptionFactoryProtocol
    let walletListLocalSubscriptionFactory: WalletListLocalSubscriptionFactoryProtocol
    let initialState: NotificationWalletListInitialState

    private var settingsProvider: StreamableProvider<Web3Alert.LocalSettings>?
    private var walletsSubscription: StreamableProvider<ManagedMetaAccountModel>?

    init(
        chainRegistry: ChainRegistryProtocol,
        initialState: NotificationWalletListInitialState,
        settingsLocalSubscriptionFactory: SettingsLocalSubscriptionFactoryProtocol,
        walletListLocalSubscriptionFactory: WalletListLocalSubscriptionFactoryProtocol
    ) {
        self.chainRegistry = chainRegistry
        self.initialState = initialState
        self.settingsLocalSubscriptionFactory = settingsLocalSubscriptionFactory
        self.walletListLocalSubscriptionFactory = walletListLocalSubscriptionFactory
    }
}

// MARK: - Private

private extension NotificationWalletListInteractor {
    func subscribeWallets() {
        walletsSubscription = subscribeAllWalletsProvider()
    }

    func subscribeChains() {
        chainRegistry.chainsSubscribe(self, runningInQueue: .main) { [weak self] changes in
            self?.presenter?.didReceiveChainChanges(changes)
        }
    }

    func subscribeSettings() {
        clear(streamableProvider: &settingsProvider)
        settingsProvider = subscribeToPushSettings()
    }

    func setupInitialState() {
        switch initialState {
        case let .modified(wallets):
            presenter?.didReceive(initialState: wallets)
        case .persisted:
            subscribeSettings()
        }
    }
}

// MARK: - NotificationWalletListInteractorInputProtocol

extension NotificationWalletListInteractor: NotificationWalletListInteractorInputProtocol {
    func setup() {
        subscribeChains()
        subscribeWallets()
    }
}

// MARK: - WalletListLocalSubscriptionHandler

extension NotificationWalletListInteractor: WalletListLocalStorageSubscriber, WalletListLocalSubscriptionHandler {
    func handleAllWallets(result: Result<[DataProviderChange<ManagedMetaAccountModel>], Error>) {
        switch result {
        case let .success(changes):
            presenter?.didReceiveWalletsChanges(changes)
        case let .failure(error):
            presenter?.didReceiveError(error)
        }
    }
}

// MARK: - SettingsSubscriptionHandler

extension NotificationWalletListInteractor: SettingsSubscriber, SettingsSubscriptionHandler {
    func handlePushNotificationsSettings(result: Result<[DataProviderChange<Web3Alert.LocalSettings>], Error>) {
        switch result {
        case let .success(changes):
            let lastChange = changes.reduceToLastChange()
            presenter?.didReceive(initialState: lastChange?.wallets)
        case let .failure(error):
            presenter?.didReceive(initialState: nil)
        }
    }
}
