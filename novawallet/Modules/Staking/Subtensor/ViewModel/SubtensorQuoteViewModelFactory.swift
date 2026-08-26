import BigInt
import Foundation

struct SubtensorStakeTargetViewModel {
    let title: String
    let subtitle: String?
}

struct SubtensorQuotePanelViewModel {
    let receive: String
    let poolFee: String
    let priceImpact: String
    let isImpactHigh: Bool
}

protocol SubtensorQuoteViewModelFactoryProtocol {
    func createTargetViewModel(
        for target: SubtensorStakeTarget,
        locale: Locale
    ) -> SubtensorStakeTargetViewModel

    func createQuotePanel(
        for quote: SubtensorQuote?,
        target: SubtensorStakeTarget,
        locale: Locale
    ) -> SubtensorQuotePanelViewModel?

    func createSlippageViewModel(
        for tolerance: BigRational,
        locale: Locale
    ) -> String?
}

final class SubtensorQuoteViewModelFactory {
    let chainAsset: ChainAsset

    private let formatterFactory = AssetBalanceFormatterFactory()

    init(chainAsset: ChainAsset) {
        self.chainAsset = chainAsset
    }
}

private extension SubtensorQuoteViewModelFactory {
    func formatAmount(
        _ amount: Balance,
        displayInfo: AssetBalanceDisplayInfo,
        locale: Locale
    ) -> String {
        let decimal = amount.decimal(assetInfo: displayInfo)

        let formatter = formatterFactory.createTokenFormatter(for: displayInfo)

        return formatter.value(for: locale).stringFromDecimal(decimal) ?? ""
    }

    func formatPercent(_ value: BigRational, locale: Locale) -> String {
        let formatter = NumberFormatter.percentSingle
        formatter.locale = locale

        return formatter.stringFromDecimal(value.decimalOrZeroValue) ?? ""
    }
}

extension SubtensorQuoteViewModelFactory: SubtensorQuoteViewModelFactoryProtocol {
    func createTargetViewModel(
        for target: SubtensorStakeTarget,
        locale: Locale
    ) -> SubtensorStakeTargetViewModel {
        switch target {
        case .root:
            return SubtensorStakeTargetViewModel(
                title: R.string(
                    preferredLanguages: locale.rLanguages
                ).localizable.stakingSubtensorRootNetwork(),
                subtitle: nil
            )
        case let .subnet(info, _):
            let symbol = info.displaySymbol
            let name = info.displayName

            return SubtensorStakeTargetViewModel(
                title: name.isEmpty ? "SN\(info.netuid)" : name,
                subtitle: [symbol, "SN\(info.netuid)"]
                    .filter { !$0.isEmpty }
                    .joined(separator: " · ")
            )
        }
    }

    func createQuotePanel(
        for quote: SubtensorQuote?,
        target: SubtensorStakeTarget,
        locale: Locale
    ) -> SubtensorQuotePanelViewModel? {
        guard case .subnet = target, let quote else {
            return nil
        }

        let receiveDisplayInfo: AssetBalanceDisplayInfo
        let feeDisplayInfo: AssetBalanceDisplayInfo

        switch quote.args.direction {
        case .stake:
            receiveDisplayInfo = target.assetDisplayInfo(basedOn: chainAsset.assetDisplayInfo)
            feeDisplayInfo = chainAsset.assetDisplayInfo
        case .unstake:
            receiveDisplayInfo = chainAsset.assetDisplayInfo
            feeDisplayInfo = target.assetDisplayInfo(basedOn: chainAsset.assetDisplayInfo)
        }

        let receive = formatAmount(
            quote.expectedOut,
            displayInfo: receiveDisplayInfo,
            locale: locale
        )

        let poolFeeAmount = formatAmount(
            quote.poolFee,
            displayInfo: feeDisplayInfo,
            locale: locale
        )

        let feeRatePercent = formatPercent(
            BigRational(
                numerator: BigUInt(quote.feeRate),
                denominator: BigUInt(SubtensorStakingPallet.perU16Denominator)
            ),
            locale: locale
        )

        let impact = quote.priceImpact ?? BigRational(numerator: 0, denominator: 1)

        return SubtensorQuotePanelViewModel(
            receive: receive.approximately(),
            poolFee: "\(poolFeeAmount) \(feeRatePercent.inParenthesis())",
            priceImpact: formatPercent(impact, locale: locale),
            isImpactHigh: SubtensorStakingFlowConstants.isHighPriceImpact(impact)
        )
    }

    func createSlippageViewModel(
        for tolerance: BigRational,
        locale: Locale
    ) -> String? {
        formatPercent(tolerance, locale: locale)
    }
}
