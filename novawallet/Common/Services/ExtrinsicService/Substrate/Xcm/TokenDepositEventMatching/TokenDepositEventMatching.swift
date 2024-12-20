import Foundation

struct TokenDepositEvent {
    let accountId: AccountId
    let amount: Balance
}

protocol TokenDepositEventMatching {
    func matchDeposit(
        event: Event,
        using codingFactory: RuntimeCoderFactoryProtocol
    ) -> TokenDepositEvent?
}
