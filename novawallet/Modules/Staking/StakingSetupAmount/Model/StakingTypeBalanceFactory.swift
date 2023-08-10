import Foundation
import BigInt

protocol StakingTypeBalanceFactoryProtocol: AnyObject {
    func getAvailableBalance(
        from assetBalance: AssetBalance?,
        stakingMethod: StakingSelectionMethod
    ) -> BigUInt?
}

final class StakingTypeBalanceFactory: StakingTypeBalanceFactoryProtocol {
    let stakingType: StakingType?

    init(stakingType: StakingType?) {
        self.stakingType = stakingType
    }

    var stakingTypeAllowsLocks: Bool {
        switch stakingType {
        case .relaychain, .auraRelaychain, .azero, .none, .parachain, .turing:
            return true
        case .nominationPools, .unsupported:
            return false
        }
    }

    private func getManualAvailableBalance(
        for assetBalance: AssetBalance?,
        stakingOption: SelectedStakingOption
    ) -> BigUInt? {
        switch stakingOption {
        case .direct:
            return assetBalance?.freeInPlank
        case .pool:
            return assetBalance?.transferable
        }
    }

    func getAvailableBalance(
        from assetBalance: AssetBalance?,
        stakingMethod: StakingSelectionMethod
    ) -> BigUInt? {
        switch stakingMethod {
        case .recommendation:
            return stakingTypeAllowsLocks ? assetBalance?.freeInPlank : assetBalance?.transferable
        case let .manual(stakingManual):
            return getManualAvailableBalance(for: assetBalance, stakingOption: stakingManual.staking)
        }
    }
}
