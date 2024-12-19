import Foundation
import SubstrateSdk

final class TokensPalletDepositEventMatcher {
    let extras: OrmlTokenExtras
    let logger: LoggerProtocol

    init(extras: OrmlTokenExtras, logger: LoggerProtocol) {
        self.extras = extras
        self.logger = logger
    }
}

extension TokensPalletDepositEventMatcher: TokenDepositEventMatching {
    func matchDeposit(
        event: Event,
        using codingFactory: RuntimeCoderFactoryProtocol
    ) -> TokenDepositEvent? {
        do {
            guard codingFactory.metadata.eventMatches(event, path: TokensPallet.depositedEventPath) else {
                return nil
            }

            let depositedEvent = try event.params.map(
                to: TokensPallet.DepositedEvent<JSON>.self,
                with: codingFactory.createRuntimeJsonContext().toRawContext()
            )

            let encoder = codingFactory.createEncoder()
            try encoder.append(json: depositedEvent.currencyId, type: extras.currencyIdType)
            let eventAssetId = try encoder.encode()
            let assetId = try Data(hexString: extras.currencyIdScale)

            guard eventAssetId == assetId else {
                return nil
            }

            return TokenDepositEvent(accountId: depositedEvent.recepient, amount: depositedEvent.amount)
        } catch {
            logger.error("Parsing failed \(error)")

            return nil
        }
    }
}
