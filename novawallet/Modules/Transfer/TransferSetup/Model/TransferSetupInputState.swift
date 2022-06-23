import Foundation

struct TransferSetupInputState {
    let recepient: AccountAddress?
    let amount: AmountInputResult?

    init(recepient: AccountAddress? = nil, amount: AmountInputResult? = nil) {
        self.recepient = recepient
        self.amount = amount
    }
}
