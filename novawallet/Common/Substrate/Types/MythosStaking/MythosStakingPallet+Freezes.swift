import Foundation

extension MythosStakingPallet {
    static let freezeModule = "CollatorStaking"
    static let stakingFreezeType = "Staking"
    static let releasingFreezeType = "Releasing"
}

extension BalancesPallet.Freezes {
    func getMythosStakingAmount() -> Balance? {
        let stakingReasons = [MythosStakingPallet.stakingFreezeType, MythosStakingPallet.releasingFreezeType]

        return filter { freeze in
            freeze.freezeId.module == MythosStakingPallet.freezeModule &&
                stakingReasons.contains(freeze.freezeId.reason)
        }
        .map(\.amount)
        .max()
    }
}
