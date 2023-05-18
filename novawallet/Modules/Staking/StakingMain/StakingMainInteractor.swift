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
    let stakingRewardsFilterRepository: AnyDataProviderRepository<StakingRewardsFilter>
    var balanceProvider: StreamableProvider<AssetBalance>?
    private var stakingRewardFiltersPeriod: StakingRewardFiltersPeriod?
    private let operationQueue: OperationQueue
    init(
        walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol,
        selectedWalletSettings: SelectedWalletSettings,
        stakingSettings: StakingAssetSettings,
        commonSettings: SettingsManagerProtocol,
        stakingRewardsFilterRepository: AnyDataProviderRepository<StakingRewardsFilter>,
        eventCenter: EventCenterProtocol,
        operationQueue: OperationQueue,
        logger: LoggerProtocol? = nil
    ) {
        self.walletLocalSubscriptionFactory = walletLocalSubscriptionFactory
        self.selectedWalletSettings = selectedWalletSettings
        self.stakingSettings = stakingSettings
        self.commonSettings = commonSettings
        self.stakingRewardsFilterRepository = stakingRewardsFilterRepository
        self.eventCenter = eventCenter
        self.operationQueue = operationQueue
        self.logger = logger
    }

    deinit {
        clearAccountInfoSubscription()
    }

    func clearAccountInfoSubscription() {
        clear(streamableProvider: &balanceProvider)
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
            presenter?.didReceiveAccountBalance(nil)
            return
        }

        balanceProvider = subscribeToAssetBalanceProvider(
            for: accountResponse.accountId,
            chainId: chainAsset.chain.chainId,
            assetId: chainAsset.asset.assetId
        )
    }

    func provideSelectedAccount() {
        guard let metaAccount = selectedWalletSettings.value else {
            return
        }

        presenter?.didReceiveSelectedAccount(metaAccount)
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

    private func provideStakingRewardsFilter() {
        guard let stakingSettings = stakingSettings.value,
              let accountId = selectedWalletSettings.value?.fetchChainAccountId(for: stakingSettings.chain.accountRequest()) else {
            return
        }
        let stakingType = StakingType(rawType: stakingSettings.asset.staking)
        let filterId = StakingRewardsFilter.createIdentifier(
            chainAccountId: accountId,
            chainAssetId: stakingSettings.chainAssetId,
            stakingType: stakingType
        )
        let fetchFilterOperation = stakingRewardsFilterRepository.fetchOperation(by: { filterId }, options: .init())

        fetchFilterOperation.completionBlock = {
            do {
                let period = try fetchFilterOperation.extractNoCancellableResultData()?.period ?? .allTime
                self.stakingRewardFiltersPeriod = period
                DispatchQueue.main.async {
                    self.presenter?.didReceiveRewardFilter(period)
                }
            } catch {
                DispatchQueue.main.async {
                    self.presenter?.didReceiveError(error)
                }
            }
        }

        operationQueue.addOperation(fetchFilterOperation)
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
                    self?.provideStakingRewardsFilter()
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

    func save(filter: StakingRewardFiltersPeriod) {
        guard let stakingSettings = stakingSettings.value,
              let accountId = selectedWalletSettings.value?.fetchChainAccountId(for: stakingSettings.chain.accountRequest()) else {
            return
        }

        let entity = StakingRewardsFilter(
            chainAccountId: accountId,
            chainAssetId: stakingSettings.chainAssetId,
            stakingType: StakingType(rawType: stakingSettings.asset.staking),
            period: filter
        )

        let saveOperation = stakingRewardsFilterRepository.saveOperation({ [entity] }, { [] })

        saveOperation.completionBlock = { [weak self] in
            self?.stakingRewardFiltersPeriod = filter

            DispatchQueue.main.async {
                if case .success = saveOperation.result {
                    self?.stakingRewardFiltersPeriod = filter
                    self?.presenter?.didReceiveRewardFilter(filter)
                }
            }
        }

        operationQueue.addOperation(saveOperation)
    }
}

extension StakingMainInteractor: EventVisitorProtocol {
    func processSelectedAccountChanged(event _: SelectedAccountChanged) {
        updateAccountSubscription()
        provideSelectedAccount()
    }
}

extension StakingMainInteractor: WalletLocalStorageSubscriber, WalletLocalSubscriptionHandler {
    func handleAssetBalance(
        result: Result<AssetBalance?, Error>,
        accountId _: AccountId,
        chainId _: ChainModel.Id,
        assetId _: AssetModel.Id
    ) {
        switch result {
        case let .success(assetBalance):
            presenter?.didReceiveAccountBalance(assetBalance)
        case let .failure(error):
            presenter?.didReceiveError(error)
        }
    }
}
