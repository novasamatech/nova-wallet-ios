import Foundation

struct StakingDashboardBuilderResult {
    enum ChangeKind {
        case reload
        case sync(Set<Multistaking.ChainAssetOption>)
    }

    let model: StakingDashboardModel
    let changeKind: ChangeKind
}
