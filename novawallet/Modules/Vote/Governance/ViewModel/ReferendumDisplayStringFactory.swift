import Foundation
import BigInt

protocol ReferendumDisplayStringFactoryProtocol {
    var formatterFactory: AssetBalanceFormatterFactoryProtocol { get }

    func createVotesValue(
        from votes: BigUInt,
        chain: ChainModel,
        locale: Locale
    ) -> String?

    func createVotes(
        from votes: BigUInt,
        chain: ChainModel,
        locale: Locale
    ) -> String?

    func createVotesDetails(
        from amount: BigUInt,
        conviction: Decimal?,
        chain: ChainModel,
        locale: Locale
    ) -> String?
}

extension ReferendumDisplayStringFactoryProtocol {
    func createVotes(
        from votes: BigUInt,
        chain: ChainModel,
        locale: Locale
    ) -> String? {
        guard let votesValueString = createVotesValue(
            from: votes,
            chain: chain,
            locale: locale
        ) else {
            return nil
        }

        return R.string(preferredLanguages: locale.rLanguages).localizable.govCommonVotesFormat(votesValueString)
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
            return R.string(preferredLanguages: locale.rLanguages
            ).localizable.govCommonAmountConvictionFormat(amountString, convictionString)
        } else {
            return nil
        }
    }
}

struct ReferendumDisplayStringFactory: ReferendumDisplayStringFactoryProtocol {
    let formatterFactory: AssetBalanceFormatterFactoryProtocol

    init(formatterFactory: AssetBalanceFormatterFactoryProtocol = AssetBalanceFormatterFactory()) {
        self.formatterFactory = formatterFactory
    }

    func createVotesValue(from votes: BigUInt, chain: ChainModel, locale: Locale) -> String? {
        guard let asset = chain.utilityAsset() else {
            return nil
        }

        let displayInfo = ChainAsset(chain: chain, asset: asset).assetDisplayInfo

        let votesDecimal = Decimal.fromSubstrateAmount(votes, precision: displayInfo.assetPrecision) ?? 0

        let displayFormatter = formatterFactory.createDisplayFormatter(for: displayInfo).value(for: locale)

        return displayFormatter.stringFromDecimal(votesDecimal)
    }
}
