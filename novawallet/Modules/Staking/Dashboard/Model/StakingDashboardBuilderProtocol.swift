import Foundation
import RobinHood

protocol StakingDashboardBuilderProtocol {
    func applyWallet(model: MetaAccountModel)
    func applyDashboardItem(changes: [DataProviderChange<Multistaking.DashboardItem>])
    func applyAssets(models: Set<ChainAsset>)
    func applyBalance(model: AssetBalance?, chainAssetId: ChainAssetId)
    func applyPrice(model: PriceData?, priceId: AssetModel.PriceId)
    func applySync(state: MultistakingSyncState)
}
