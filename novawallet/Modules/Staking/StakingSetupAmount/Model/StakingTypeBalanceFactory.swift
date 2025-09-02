import Foundation
import BigInt

protocol StakingTypeBalanceFactoryProtocol: AnyObject {
    func getAvailableBalance(
        from assetBalance: AssetBalance?,
        stakingMethod: StakingSelectionMethod
    ) -> BigUInt?

    func getStakeableBalance(
        from assetBalance: AssetBalance?,
        existentialDeposit: BigUInt?,
        stakingMethod: StakingSelectionMethod
    ) -> BigUInt?
}

extension StakingTypeBalanceFactoryProtocol {
    func getAvailableBalance(from assetBalance: AssetBalance?) -> BigUInt? {
        getAvailableBalance(from: assetBalance, stakingMethod: .recommendation(nil))
    }
}

final class StakingTypeBalanceFactory: StakingTypeBalanceFactoryProtocol {
    let stakingType: StakingType?

    init(stakingType: StakingType?) {
        self.stakingType = stakingType
    }

    var stakingTypeAllowsLocks: Bool {
        switch stakingType {
        case .relaychain, .auraRelaychain, .azero, .none, .parachain, .turing, .mythos:
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

    func getStakeableBalance(
        from assetBalance: AssetBalance?,
        existentialDeposit: BigUInt?,
        stakingMethod: StakingSelectionMethod
    ) -> BigUInt? {
        let optAvailableBalance = getAvailableBalance(from: assetBalance, stakingMethod: stakingMethod)

        switch stakingMethod.selectedStakingOption {
        case .pool:
            guard
                let existentialDeposit = existentialDeposit,
                let assetBalance = assetBalance,
                let availableBalance = optAvailableBalance else {
                return optAvailableBalance
            }

            let totalMinusEd = assetBalance.totalInPlank >= existentialDeposit ?
                assetBalance.totalInPlank - existentialDeposit : 0

            return min(availableBalance, totalMinusEd)
        case .none, .direct:
            return optAvailableBalance
        }
    }
}
