import Foundation
import Keystore_iOS
import Operation_iOS

struct MultisigNotificationsPromoParams: Equatable {
    let selectedWallets: [Web3Alert.LocalWallet]
    let completion: () -> Void

    static func == (
        lhs: MultisigNotificationsPromoParams,
        rhs: MultisigNotificationsPromoParams
    ) -> Bool {
        lhs.selectedWallets == rhs.selectedWallets
    }
}

enum MultisigNotificationsPromoState: Equatable {
    case shown
    case requestingShow(MultisigNotificationsPromoParams)
}

protocol MultisigNotificationsPromoServiceProtocol: AnyProviderAutoCleaning {
    func add(
        observer: AnyObject,
        sendStateOnSubscription: Bool,
        queue: DispatchQueue?,
        closure: @escaping Observable<MultisigNotificationsPromoState?>.StateChangeClosure
    )
    func remove(observer: AnyObject)
    func reset()
}

final class MultisigNotificationsPromoService: BaseObservableStateStore<MultisigNotificationsPromoState> {
    let walletListLocalSubscriptionFactory: WalletListLocalSubscriptionFactoryProtocol

    private let settingsManager: SettingsManagerProtocol
    private let notificationsSettingsrepository: AnyDataProviderRepository<Web3Alert.LocalSettings>
    private let operationQueue: OperationQueue
    private let workingQueue: DispatchQueue

    private var multisigwWalletListProvider: StreamableProvider<ManagedMetaAccountModel>?

    init(
        settingsManager: SettingsManagerProtocol,
        walletListLocalSubscriptionFactory: WalletListLocalSubscriptionFactoryProtocol,
        notificationsSettingsrepository: AnyDataProviderRepository<Web3Alert.LocalSettings>,
        operationQueue: OperationQueue,
        workingQueue: DispatchQueue,
        logger: LoggerProtocol
    ) {
        self.settingsManager = settingsManager
        self.walletListLocalSubscriptionFactory = walletListLocalSubscriptionFactory
        self.notificationsSettingsrepository = notificationsSettingsrepository
        self.operationQueue = operationQueue
        self.workingQueue = workingQueue

        super.init(logger: logger)

        setup()
    }
}

// MARK: - Private

private extension MultisigNotificationsPromoService {
    func setup() {
        guard !settingsManager.multisigNotificationsPromoSeen else {
            stateObservable.state = .shown
            return
        }

        multisigwWalletListProvider = subscribeForWallets(of: .multisig)
    }

    func checkMultisigNotificationsPromo(for wallets: [ManagedMetaAccountModel]) {
        let allMultisigAccounts = wallets.compactMap { $0.info.multisigAccount?.anyChainMultisig }

        guard allMultisigAccounts.contains(where: { $0.status == .active }) else { return }

        clear(streamableProvider: &multisigwWalletListProvider)

        let selectedWalletsOepration = notificationsSettingsrepository.fetchAllOperation(with: .init())

        execute(
            operation: selectedWalletsOepration,
            inOperationQueue: operationQueue,
            runningCallbackIn: workingQueue
        ) { [weak self] result in
            guard let wallets = try? result.get() else { return }

            let params = MultisigNotificationsPromoParams(selectedWallets: wallets.flatMap(\.wallets)) {
                self?.settingsManager.multisigNotificationsPromoSeen = true
                self?.stateObservable.state = .shown
            }

            self?.stateObservable.state = .requestingShow(params)
        }
    }
}

// MARK: - WalletListLocalSubscriptionHandler

extension MultisigNotificationsPromoService: WalletListLocalStorageSubscriber, WalletListLocalSubscriptionHandler {
    func handleWallets(
        result: Result<[DataProviderChange<ManagedMetaAccountModel>], any Error>,
        of _: MetaAccountModelType
    ) {
        guard
            let allWallets = try? result.get().allChangedItems(),
            !allWallets.isEmpty
        else { return }

        checkMultisigNotificationsPromo(for: allWallets)
    }
}

// MARK: - MultisigNotificationsPromoServiceProtocol

extension MultisigNotificationsPromoService: MultisigNotificationsPromoServiceProtocol {}
