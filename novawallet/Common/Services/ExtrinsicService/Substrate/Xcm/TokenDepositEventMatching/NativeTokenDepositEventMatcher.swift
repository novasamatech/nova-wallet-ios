import Foundation
import SubstrateSdk

final class NativeTokenDepositEventMatcher: TokenDepositEventMatching {
    func matchDeposit(
        event: Event,
        using codingFactory: RuntimeCoderFactoryProtocol
    ) -> TokenDepositEvent? {
        do {
            guard codingFactory.metadata.eventMatches(event, path: BalancesPallet.balancesMinted) else {
                return nil
            }

            let mintedEvent = try event.params.map(
                to: BalancesPallet.MintedEvent.self,
                with: codingFactory.createRuntimeJsonContext().toRawContext()
            )

            return TokenDepositEvent(accountId: mintedEvent.accountId, amount: mintedEvent.amount)
        } catch {
            return nil
        }
    }
}
