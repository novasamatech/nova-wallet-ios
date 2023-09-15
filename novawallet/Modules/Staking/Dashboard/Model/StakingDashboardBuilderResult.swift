import Foundation

struct StakingDashboardBuilderResult {
    struct SyncChange {
        let byStakingOption: Set<Multistaking.ChainAssetOption>
        let byStakingChainAsset: Set<ChainAsset>
    }

    enum ChangeKind {
        case reload
        case sync(SyncChange)
    }

    let walletId: MetaAccountModel.Id?
    let model: StakingDashboardModel
    let changeKind: ChangeKind
}
