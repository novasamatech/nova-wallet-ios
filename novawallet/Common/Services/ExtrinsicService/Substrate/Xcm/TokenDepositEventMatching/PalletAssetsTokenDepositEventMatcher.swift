import Foundation

final class PalletAssetsTokenDepositEventMatcher {
    let extras: StatemineAssetExtras
    let logger: LoggerProtocol

    init(extras: StatemineAssetExtras, logger: LoggerProtocol) {
        self.extras = extras
        self.logger = logger
    }
}

extension PalletAssetsTokenDepositEventMatcher: TokenDepositEventMatching {
    func matchDeposit(
        event: Event,
        using codingFactory: RuntimeCoderFactoryProtocol
    ) -> TokenDepositEvent? {
        do {
            guard codingFactory.metadata.eventMatches(
                event,
                path: PalletAssets.issuedPath(for: extras.palletName)
            ) else {
                return nil
            }

            let mintedEvent = try event.params.map(
                to: PalletAssets.IssuedEvent.self,
                with: codingFactory.createRuntimeJsonContext().toRawContext()
            )

            let assetIdAsString = try StatemineAssetSerializer.encode(
                assetId: mintedEvent.assetId,
                palletName: extras.palletName,
                codingFactory: codingFactory
            )

            guard extras.assetId == assetIdAsString else {
                return nil
            }

            return TokenDepositEvent(accountId: mintedEvent.accountId, amount: mintedEvent.amount)
        } catch {
            logger.error("Parsing failed \(error)")

            return nil
        }
    }
}
