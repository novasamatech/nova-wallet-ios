import Foundation
import SubstrateSdk

final class NativeTokenDepositedEventMatcher: TokenDepositEventMatching {
    let logger: LoggerProtocol

    init(logger: LoggerProtocol) {
        self.logger = logger
    }

    func matchDeposit(
        event: Event,
        using codingFactory: RuntimeCoderFactoryProtocol
    ) -> TokenDepositEvent? {
        do {
            guard codingFactory.metadata.eventMatches(event, path: BalancesPallet.balancesDeposit) else {
                return nil
            }

            let depositEvent = try event.params.map(
                to: BalancesPallet.DepositEvent.self,
                with: codingFactory.createRuntimeJsonContext().toRawContext()
            )

            return TokenDepositEvent(accountId: depositEvent.accountId, amount: depositEvent.amount)
        } catch {
            logger.error("Parsing failed: \(error)")

            return nil
        }
    }
}
