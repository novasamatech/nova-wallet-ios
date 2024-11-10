import Foundation
import SubstrateSdk

final class TokensPalletDepositEventMatcher {
    let extras: OrmlTokenExtras

    init(extras: OrmlTokenExtras) {
        self.extras = extras
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
            return nil
        }
    }
}
