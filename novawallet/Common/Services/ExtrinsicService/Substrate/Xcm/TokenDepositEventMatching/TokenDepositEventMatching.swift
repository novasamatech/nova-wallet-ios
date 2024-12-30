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

final class TokenFirstOfDepositEventMatcher: TokenDepositEventMatching {
    let matchers: [TokenDepositEventMatching]

    init(matchers: [TokenDepositEventMatching]) {
        self.matchers = matchers
    }
}

extension TokenFirstOfDepositEventMatcher {
    func matchDeposit(
        event: Event,
        using codingFactory: RuntimeCoderFactoryProtocol
    ) -> TokenDepositEvent? {
        for matcher in matchers {
            if let depositEvent = matcher.matchDeposit(event: event, using: codingFactory) {
                return depositEvent
            }
        }

        return nil
    }
}
