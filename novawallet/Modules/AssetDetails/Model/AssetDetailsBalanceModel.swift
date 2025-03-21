import Foundation

struct AssetDetailsBalanceModel {
    let total: AssetDetailsInteractiveBalanceModel
    let locked: AssetDetailsInteractiveBalanceModel
    let transferrable: BalanceViewModelProtocol
}

struct AssetDetailsInteractiveBalanceModel {
    let balance: BalanceViewModelProtocol
    let interactive: Bool
}
