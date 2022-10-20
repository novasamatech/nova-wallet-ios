import Foundation
import BigInt

protocol ReferendumDisplayStringFactoryProtocol {
    func createVotes(from votes: BigUInt, chain: ChainModel, locale: Locale) -> String?

    func createVotesDetails(
        from amount: BigUInt,
        conviction: Decimal?,
        chain: ChainModel,
        locale: Locale
    ) -> String?
}

final class ReferendumDisplayStringFactory: ReferendumDisplayStringFactoryProtocol {
    let formatterFactory: AssetBalanceFormatterFactoryProtocol

    init(formatterFactory: AssetBalanceFormatterFactoryProtocol = AssetBalanceFormatterFactory()) {
        self.formatterFactory = formatterFactory
    }

    func createVotes(from votes: BigUInt, chain: ChainModel, locale: Locale) -> String? {
        guard let asset = chain.utilityAsset() else {
            return nil
        }

        let displayInfo = ChainAsset(chain: chain, asset: asset).assetDisplayInfo

        let votesDecimal = Decimal.fromSubstrateAmount(votes, precision: displayInfo.assetPrecision) ?? 0

        let displayFormatter = formatterFactory.createDisplayFormatter(for: displayInfo).value(for: locale)

        if let votesValueString = displayFormatter.stringFromDecimal(votesDecimal) {
            return R.string.localizable.govCommonVotesFormat(votesValueString, preferredLanguages: locale.rLanguages)
        } else {
            return nil
        }
    }

    func createVotesDetails(
        from amount: BigUInt,
        conviction: Decimal?,
        chain: ChainModel,
        locale: Locale
    ) -> String? {
        guard let asset = chain.utilityAsset() else {
            return nil
        }

        let displayInfo = ChainAsset(chain: chain, asset: asset).assetDisplayInfo

        let displayFormatter = formatterFactory.createDisplayFormatter(for: displayInfo).value(for: locale)
        let tokenFormatter = formatterFactory.createTokenFormatter(for: displayInfo).value(for: locale)

        let optConvictionString = displayFormatter.stringFromDecimal(conviction ?? 0)

        let amountDecimal = Decimal.fromSubstrateAmount(amount, precision: displayInfo.assetPrecision) ?? 0
        let optAmountString = tokenFormatter.stringFromDecimal(amountDecimal)

        if let convictionString = optConvictionString, let amountString = optAmountString {
            return R.string.localizable.govCommonAmountConvictionFormat(
                amountString,
                convictionString,
                preferredLanguages: locale.rLanguages
            )
        } else {
            return nil
        }
    }
}
