import Foundation

enum SubtensorShieldEligibility {
    static func supports(operation: SubtensorOperation) -> Bool {
        switch operation {
        case let .subnetBuy(_, netuid, _, _, _),
             let .subnetSell(_, netuid, _, _, _, _),
             let .subnetSellGroup(_, _, netuid, _, _, _):
            netuid != SubtensorPallet.rootNetuid
        case .rootStake, .rootUnstake, .rootUnstakeGroup, .rootClaim:
            false
        }
    }

    static func supports(walletType: MetaAccountModelType) -> Bool {
        walletType == .secrets
    }
}
