import Foundation
import Operation_iOS

protocol AssetDetailsBittensorEarnDelegate: AnyObject {
    func didReceiveBittensorEarn(isEnabled: Bool)
    func didReceiveBittensorEarn(hasPositions: Bool)
    func didReceiveBittensorEarn(error: AssetDetailsError)
}

protocol AssetDetailsBittensorEarnSourceProtocol: AnyObject {
    var delegate: AssetDetailsBittensorEarnDelegate? { get set }

    func setup()
}

final class AssetDetailsBittensorEarnSource {
    weak var delegate: AssetDetailsBittensorEarnDelegate?

    let chainAsset: ChainAsset
    let walletId: MetaAccountModel.Id
    let earnConfigProvider: SubtensorEarnConfigProviderProtocol
    let stakingDashboardProviderFactory: StakingDashboardProviderFactoryProtocol
    let operationQueue: OperationQueue

    private let configCallStore = CancellableCallStore()
    private var dashboardItemsProvider: StreamableProvider<Multistaking.DashboardItem>?
    private var dashboardItems: [Multistaking.DashboardItem] = []

    init(
        chainAsset: ChainAsset,
        walletId: MetaAccountModel.Id,
        earnConfigProvider: SubtensorEarnConfigProviderProtocol,
        stakingDashboardProviderFactory: StakingDashboardProviderFactoryProtocol,
        operationQueue: OperationQueue
    ) {
        self.chainAsset = chainAsset
        self.walletId = walletId
        self.earnConfigProvider = earnConfigProvider
        self.stakingDashboardProviderFactory = stakingDashboardProviderFactory
        self.operationQueue = operationQueue
    }

    deinit {
        configCallStore.cancel()
    }
}

private extension AssetDetailsBittensorEarnSource {
    func fetchConfig() {
        executeCancellable(
            wrapper: earnConfigProvider.createConfigWrapper(),
            inOperationQueue: operationQueue,
            backingCallIn: configCallStore,
            runningCallbackIn: .main
        ) { [weak self] result in
            guard let self else {
                return
            }

            switch result {
            case let .success(config):
                let isEnabled = BittensorLocalBanner.isEarnActionAvailable(on: chainAsset, config: config)
                delegate?.didReceiveBittensorEarn(isEnabled: isEnabled)
            case let .failure(error):
                delegate?.didReceiveBittensorEarn(error: .earnConfig(error))
            }
        }
    }
}

extension AssetDetailsBittensorEarnSource: AssetDetailsBittensorEarnSourceProtocol {
    func setup() {
        guard BittensorLocalBanner.chainAsset(for: chainAsset.chain)?.chainAssetId == chainAsset.chainAssetId else {
            return
        }

        dashboardItemsProvider = subscribeDashboardItems(for: walletId, chainAssetId: chainAsset.chainAssetId)

        fetchConfig()
    }
}

extension AssetDetailsBittensorEarnSource: StakingDashboardLocalStorageSubscriber,
    StakingDashboardLocalStorageHandler {
    func handleDashboardItems(
        _ result: Result<[DataProviderChange<Multistaking.DashboardItem>], Error>,
        walletId _: MetaAccountModel.Id,
        chainAssetId _: ChainAssetId
    ) {
        switch result {
        case let .success(changes):
            dashboardItems = dashboardItems.applying(changes: changes)

            let hasPositions = dashboardItems.contains { item in
                item.stakingOption.option.type == .subtensor && item.hasStaking
            }

            delegate?.didReceiveBittensorEarn(hasPositions: hasPositions)
        case let .failure(error):
            delegate?.didReceiveBittensorEarn(error: .stakingDashboard(error))
        }
    }
}
