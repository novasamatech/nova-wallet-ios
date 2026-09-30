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
    let stakingDashboardProviderFactory: StakingDashboardProviderFactoryProtocol

    private var dashboardItemsProvider: StreamableProvider<Multistaking.DashboardItem>?
    private var dashboardItems: [Multistaking.DashboardItem] = []

    init(
        chainAsset: ChainAsset,
        walletId: MetaAccountModel.Id,
        stakingDashboardProviderFactory: StakingDashboardProviderFactoryProtocol
    ) {
        self.chainAsset = chainAsset
        self.walletId = walletId
        self.stakingDashboardProviderFactory = stakingDashboardProviderFactory
    }

    static func isEarnAvailable(on chainAsset: ChainAsset) -> Bool {
        chainAsset.asset.hasSubtensorStaking
    }
}

extension AssetDetailsBittensorEarnSource: AssetDetailsBittensorEarnSourceProtocol {
    func setup() {
        guard Self.isEarnAvailable(on: chainAsset) else {
            return
        }

        dashboardItemsProvider = subscribeDashboardItems(for: walletId, chainAssetId: chainAsset.chainAssetId)

        delegate?.didReceiveBittensorEarn(isEnabled: true)
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
