import Foundation
import Keystore_iOS
import Operation_iOS
import SubstrateSdk
import Foundation_iOS

final class StakingMainInteractor: AnyProviderAutoCleaning {
    weak var presenter: StakingMainInteractorOutputProtocol?

    let ahmInfoFactory: AHMFullInfoFactoryProtocol
    let settingsManager: SettingsManagerProtocol
    let selectedWalletSettings: SelectedWalletSettings
    let stakingOption: Multistaking.ChainAssetOption
    let stakingRewardsFilterRepository: AnyDataProviderRepository<StakingRewardsFilter>
    let operationQueue: OperationQueue
    let eventCenter: EventCenterProtocol
    let logger: LoggerProtocol

    var chainAsset: ChainAsset { stakingOption.chainAsset }

    private var stakingRewardFiltersPeriod: StakingRewardFiltersPeriod?

    init(
        ahmInfoFactory: AHMFullInfoFactoryProtocol,
        settingsManager: SettingsManagerProtocol,
        stakingOption: Multistaking.ChainAssetOption,
        selectedWalletSettings: SelectedWalletSettings,
        eventCenter: EventCenterProtocol,
        stakingRewardsFilterRepository: AnyDataProviderRepository<StakingRewardsFilter>,
        operationQueue: OperationQueue,
        logger: LoggerProtocol
    ) {
        self.ahmInfoFactory = ahmInfoFactory
        self.settingsManager = settingsManager
        self.stakingOption = stakingOption
        self.eventCenter = eventCenter
        self.selectedWalletSettings = selectedWalletSettings
        self.stakingRewardsFilterRepository = stakingRewardsFilterRepository
        self.operationQueue = operationQueue
        self.logger = logger
    }

    private func provideStakingRewardsFilter() {
        guard let wallet = selectedWalletSettings.value,
              let selectedAccount = wallet.fetchMetaChainAccount(for: chainAsset.chain.accountRequest()) else {
            return
        }
        let stakingType = StakingType(rawType: stakingOption.type.rawValue)
        let filterId = StakingRewardsFilter.createIdentifier(
            chainAccountId: selectedAccount.chainAccount.accountId,
            chainAssetId: chainAsset.chainAssetId,
            stakingType: stakingType
        )
        let fetchFilterOperation = stakingRewardsFilterRepository.fetchOperation(by: { filterId }, options: .init())

        fetchFilterOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                guard let self = self else {
                    return
                }
                do {
                    let period = try fetchFilterOperation.extractNoCancellableResultData()?.period ?? .allTime
                    self.stakingRewardFiltersPeriod = period
                    self.presenter?.didReceiveRewardFilter(period)
                } catch {
                    self.logger.error("Fetch error: \(error)")
                }
            }
        }

        operationQueue.addOperation(fetchFilterOperation)
    }

    func ahmDestinationChainMatchIfExists(info: AHMFullInfo?) -> Bool {
        guard let info else { return true }

        return info.destinationChain.chainId == chainAsset.chain.chainId
    }

    func provideAHMInfo() {
        guard let parentChainId = chainAsset.chain.parentId else {
            return
        }

        let fetchWrapper = ahmInfoFactory.fetch(by: parentChainId)

        execute(
            wrapper: fetchWrapper,
            inOperationQueue: operationQueue,
            runningCallbackIn: .main
        ) { [weak self] result in
            guard let self else { return }

            switch result {
            case let .success(info):
                guard ahmDestinationChainMatchIfExists(info: info) else {
                    return
                }

                presenter?.didReceiveAHMInfo(info)
            case let .failure(error):
                logger.error("Failed on fetch AHM info: \(error)")
            }
        }
    }
}

extension StakingMainInteractor: StakingMainInteractorInputProtocol {
    func setup() {
        presenter?.didReceiveExpansion(settingsManager.stakingNetworkExpansion)

        provideAHMInfo()
        provideStakingRewardsFilter()

        eventCenter.add(observer: self, dispatchIn: .main)
    }

    func saveNetworkInfoViewExpansion(isExpanded: Bool) {
        settingsManager.stakingNetworkExpansion = isExpanded
    }

    func save(filter: StakingRewardFiltersPeriod) {
        guard let settings = selectedWalletSettings.value,
              let selectedAccount = settings.fetchMetaChainAccount(for: chainAsset.chain.accountRequest()) else {
            return
        }

        let entity = StakingRewardsFilter(
            chainAccountId: selectedAccount.chainAccount.accountId,
            chainAssetId: chainAsset.chainAssetId,
            stakingType: stakingOption.type,
            period: filter
        )

        let saveOperation = stakingRewardsFilterRepository.saveOperation({ [entity] }, { [] })

        saveOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                do {
                    _ = try saveOperation.extractNoCancellableResultData()
                    self?.stakingRewardFiltersPeriod = filter
                    self?.presenter?.didReceiveRewardFilter(filter)
                } catch {
                    self?.logger.error("Save error: \(error)")
                }
            }
        }

        operationQueue.addOperation(saveOperation)
    }

    func closeAHMAlert() {
        guard let parentChainId = chainAsset.chain.parentId else {
            return
        }

        settingsManager.ahmStakingAlertClosedChains.add(parentChainId)
        provideAHMInfo()
    }
}

extension StakingMainInteractor: EventVisitorProtocol {
    func processSelectedWalletChanged(event _: SelectedWalletSwitched) {
        provideStakingRewardsFilter()
    }
}
