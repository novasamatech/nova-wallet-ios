import Foundation
import SoraKeystore
import RobinHood
import SubstrateSdk
import SoraFoundation

final class StakingMainInteractor: AnyProviderAutoCleaning {
    weak var presenter: StakingMainInteractorOutputProtocol?

    let stakingSettings: StakingAssetSettings

    let selectedWalletSettings: SelectedWalletSettings
    let walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol

    let commonSettings: SettingsManagerProtocol
    let eventCenter: EventCenterProtocol
    let logger: LoggerProtocol?

    var balanceProvider: AnyDataProvider<DecodedAccountInfo>?

    init(
        walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol,
        selectedWalletSettings: SelectedWalletSettings,
        stakingSettings: StakingAssetSettings,
        commonSettings: SettingsManagerProtocol,
        eventCenter: EventCenterProtocol,
        logger: LoggerProtocol? = nil
    ) {
        self.walletLocalSubscriptionFactory = walletLocalSubscriptionFactory
        self.selectedWalletSettings = selectedWalletSettings
        self.stakingSettings = stakingSettings
        self.commonSettings = commonSettings
        self.eventCenter = eventCenter
        self.logger = logger
    }

    deinit {
        clearAccountInfoSubscription()
    }

    func clearAccountInfoSubscription() {
        clear(dataProvider: &balanceProvider)
    }

    func performAccountInfoSubscription() {
        guard
            let selectedAccount = selectedWalletSettings.value,
            let chainAsset = stakingSettings.value else {
            presenter?.didReceiveError(PersistentValueSettingsError.missingValue)
            return
        }

        guard let accountResponse = selectedAccount.fetch(
            for: chainAsset.chain.accountRequest()
        ) else {
            presenter?.didReceiveError(ChainAccountFetchingError.accountNotExists)
            return
        }

        balanceProvider = subscribeToAccountInfoProvider(
            for: accountResponse.accountId,
            chainId: chainAsset.chain.chainId
        )
    }

    func provideSelectedAccount() {
        guard
            let chainRequest = stakingSettings.value?.chain.accountRequest(),
            let metaAccount = selectedWalletSettings.value,
            let accountResponse = metaAccount.fetchMetaChainAccount(for: chainRequest) else {
            return
        }

        presenter?.didReceiveSelectedAccount(accountResponse)
    }

    func provideNewChain() {
        presenter?.didReceiveStakingSettings(stakingSettings)
    }

    func updateAccountSubscription() {
        clearAccountInfoSubscription()
        performAccountInfoSubscription()
    }

    func continueSetup() {
        eventCenter.add(observer: self, dispatchIn: .main)

        presenter?.didReceiveExpansion(commonSettings.stakingNetworkExpansion)
    }
}

extension StakingMainInteractor: StakingMainInteractorInputProtocol {
    func setup() {
        DispatchQueue.global(qos: .userInteractive).async { [weak self] in
            self?.stakingSettings.setup(runningCompletionIn: .main) { result in
                switch result {
                case .success:
                    self?.continueSetup()
                    self?.provideNewChain()
                    self?.provideSelectedAccount()
                    self?.updateAccountSubscription()
                case let .failure(error):
                    self?.logger?.error("Staking settings setup error: \(error)")
                    self?.presenter?.didReceiveError(error)
                }
            }
        }
    }

    func save(chainAsset: ChainAsset) {
        guard stakingSettings.value?.chainAssetId != chainAsset.chainAssetId else {
            return
        }

        stakingSettings.save(value: chainAsset, runningCompletionIn: .main) { [weak self] _ in
            self?.provideNewChain()
            self?.provideSelectedAccount()
            self?.updateAccountSubscription()
        }
    }

    func saveNetworkInfoViewExpansion(isExpanded: Bool) {
        commonSettings.stakingNetworkExpansion = isExpanded
    }
}

extension StakingMainInteractor: EventVisitorProtocol {
    func processSelectedAccountChanged(event _: SelectedAccountChanged) {
        updateAccountSubscription()
    }
}

extension StakingMainInteractor: WalletLocalStorageSubscriber, WalletLocalSubscriptionHandler {
    func handleAccountInfo(
        result: Result<AccountInfo?, Error>,
        accountId _: AccountId,
        chainId _: ChainModel.Id
    ) {
        switch result {
        case let .success(accountInfo):
            presenter?.didReceiveAccountInfo(accountInfo)
        case let .failure(error):
            presenter?.didReceiveError(error)
        }
    }
}
