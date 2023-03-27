import Foundation
import CommonWallet

struct SelectValidatorsConfirmationModel {
    let wallet: WalletDisplayAddress
    let amount: Decimal
    let rewardDestination: RewardDestination<DisplayAddress>
    let targets: [SelectedValidatorInfo]
    let maxTargets: Int
    let hasExistingBond: Bool
    let hasExistingNomination: Bool

    var existingBond: Decimal {
        hasExistingBond ? amount : 0
    }

    var amountToBond: Decimal {
        !hasExistingBond ? amount : 0
    }
}
