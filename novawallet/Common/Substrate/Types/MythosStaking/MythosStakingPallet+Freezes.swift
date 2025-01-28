import Foundation

extension MythosStakingPallet {
    static let freezeModule = "CollatorStaking"
    static let stakingFreezeType = "Staking"
    static let releasingFreezeType = "Releasing"
    static let candidacyBondFreezeType = "CandidacyBond"
}

extension BalancesPallet.Freezes {
    func getMythosStakingAmount() -> Balance? {
        let stakingReasons = [
            MythosStakingPallet.stakingFreezeType,
            MythosStakingPallet.releasingFreezeType,
            MythosStakingPallet.candidacyBondFreezeType
        ]

        return filter { freeze in
            freeze.freezeId.module == MythosStakingPallet.freezeModule &&
                stakingReasons.contains(freeze.freezeId.reason)
        }
        .map(\.amount)
        .max()
    }
}
