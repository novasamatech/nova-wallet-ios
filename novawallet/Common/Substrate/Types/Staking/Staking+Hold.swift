import Foundation

extension Staking {
    static var holdId: BalancesPallet.HoldId {
        BalancesPallet.HoldId(module: "Staking", reason: "Staking")
    }
}
