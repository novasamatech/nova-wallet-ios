import Foundation

struct MythosStakeModel {
    struct Amount {
        let toLock: Balance
        let toStake: Balance

        init(toLock: Balance = 0, toStake: Balance = 0) {
            self.toLock = toLock
            self.toStake = toStake
        }
    }

    let amount: Amount
    let collator: AccountId

    var reuseTxId: String {
        [
            String(amount.toLock),
            collator.toHex(),
            String(amount.toStake)
        ].joined(with: String.Separator.dash)
    }
}
