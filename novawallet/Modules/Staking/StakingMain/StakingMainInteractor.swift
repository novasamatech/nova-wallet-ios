import Foundation
import Keystore_iOS
import Operation_iOS
import SubstrateSdk
import Foundation_iOS

final class StakingMainInteractor: AnyProviderAutoCleaning {
    weak var presenter: StakingMainInteractorOutputProtocol?

    let ahmInfoFactory: AHMFullInfoFactoryProtocol
    let selectedWalletSettings: SelectedWalletSettings
    let commonSettings: SettingsManagerProtocol
    let stakingOption: Multistaking.ChainAssetOption
    let stakingRewardsFilterRepository: AnyDataProviderRepository<StakingRewardsFilter>
    let operationQueue: OperationQueue
    let eventCenter: EventCenterProtocol
    let logger: LoggerProtocol

    var chainAsset: ChainAsset { stakingOption.chainAsset }

    private var stakingRewardFiltersPeriod: StakingRewardFiltersPeriod?

    init(
        ahmInfoFactory: AHMFullInfoFactoryProtocol,
        stakingOption: Multistaking.ChainAssetOption,
        selectedWalletSettings: SelectedWalletSettings,
        commonSettings: SettingsManagerProtocol,
        eventCenter: EventCenterProtocol,
        stakingRewardsFilterRepository: AnyDataProviderRepository<StakingRewardsFilter>,
        operationQueue: OperationQueue,
        logger: LoggerProtocol
    ) {
        self.ahmInfoFactory = ahmInfoFactory
        self.stakingOption = stakingOption
        self.commonSettings = commonSettings
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

    func provideAHMInfo() {
        let fetchWrapper = ahmInfoFactory.fetch(by: chainAsset.chain.chainId)

        execute(
            wrapper: fetchWrapper,
            inOperationQueue: operationQueue,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case let .success(info):
                guard let info else { return }

                self?.presenter?.didReceiveAHMInfo(info)
            case let .failure(error):
                self?.logger.error("Failed on fetch AHM info: \(error)")
            }
        }
    }
}

extension StakingMainInteractor: StakingMainInteractorInputProtocol {
    func setup() {
        presenter?.didReceiveExpansion(commonSettings.stakingNetworkExpansion)

        provideAHMInfo()
        provideStakingRewardsFilter()

        eventCenter.add(observer: self, dispatchIn: .main)
    }

    func saveNetworkInfoViewExpansion(isExpanded: Bool) {
        commonSettings.stakingNetworkExpansion = isExpanded
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
}

extension StakingMainInteractor: EventVisitorProtocol {
    func processSelectedWalletChanged(event _: SelectedWalletSwitched) {
        provideStakingRewardsFilter()
    }
}
