import Foundation
import SubstrateSdk

// Tokens and Currencies pallets share the same deposited event structure
// Select which pallet to use by providing event path
final class TokensPalletDepositEventMatcher {
    let extras: OrmlTokenExtras
    let logger: LoggerProtocol
    let eventPath: EventCodingPath

    init(
        extras: OrmlTokenExtras,
        eventPath: EventCodingPath = TokensPallet.depositedEventPath,
        logger: LoggerProtocol
    ) {
        self.extras = extras
        self.eventPath = eventPath
        self.logger = logger
    }
}

extension TokensPalletDepositEventMatcher: TokenDepositEventMatching {
    func matchDeposit(
        event: Event,
        using codingFactory: RuntimeCoderFactoryProtocol
    ) -> TokenDepositEvent? {
        do {
            guard codingFactory.metadata.eventMatches(event, path: eventPath) else {
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
