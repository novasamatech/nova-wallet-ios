import Foundation

struct StakingDashboardBuilderResult {
    enum ChangeKind {
        case reload
        case sync(Set<Multistaking.ChainAssetOption>)
    }

    let walletId: MetaAccountModel.Id?
    let model: StakingDashboardModel
    let changeKind: ChangeKind
}
