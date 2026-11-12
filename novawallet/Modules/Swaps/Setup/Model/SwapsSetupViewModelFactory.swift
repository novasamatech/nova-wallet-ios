import Foundation
import Foundation_iOS
import BigInt

protocol SwapsSetupViewModelFactoryProtocol: SwapBaseViewModelFactoryProtocol, SwapIssueViewModelFactoryProtocol {
    func buttonState(for issueParams: SwapIssueCheckParams, locale: Locale) -> ButtonState

    func payTitleViewModel(
        assetDisplayInfo: AssetBalanceDisplayInfo?,
        maxValue: Decimal?,
        locale: Locale
    ) -> TitleHorizontalMultiValueView.Model

    func payAssetViewModel(chainAsset: ChainAsset?, locale: Locale) -> SwapAssetInputViewModel

    func inputPriceViewModel(
        assetDisplayInfo: AssetBalanceDisplayInfo,
        amount: Decimal?,
        priceData: PriceData?,
        locale: Locale
    ) -> String?

    func receiveTitleViewModel(
        assetDisplayInfo: AssetBalanceDisplayInfo?,
        balance: Balance?,
        locale: Locale
    ) -> TitleHorizontalMultiValueView.Model

    func slippageViewModel(
        slippage: BigRational,
        bounds: SlippageBounds,
        locale: Locale
    ) -> SwapSetupSlippageViewModel

    func minReceivedViewModel(
        for quote: AssetExchangeQuote,
        slippage: BigRational,
        chainAsset: ChainAsset,
        locale: Locale
    ) -> String

    func receiveAssetViewModel(chainAsset: ChainAsset?, locale: Locale) -> SwapAssetInputViewModel

    func amountInputViewModel(
        chainAsset: ChainAsset,
        amount: Decimal?,
        locale: Locale
    ) -> AmountInputViewModelProtocol

    func amountFromValue(_ decimal: Decimal, chainAsset: ChainAsset, locale: Locale) -> String
}

final class SwapsSetupViewModelFactory: SwapBaseViewModelFactory {
    let issuesViewModelFactory: SwapIssueViewModelFactoryProtocol
    let networkViewModelFactory: NetworkViewModelFactoryProtocol
    let assetIconViewModelFactory: AssetIconViewModelFactoryProtocol

    init(
        balanceViewModelFactoryFacade: BalanceViewModelFactoryFacadeProtocol,
        priceAssetInfoFactory: PriceAssetInfoFactoryProtocol,
        issuesViewModelFactory: SwapIssueViewModelFactoryProtocol,
        networkViewModelFactory: NetworkViewModelFactoryProtocol,
        assetIconViewModelFactory: AssetIconViewModelFactoryProtocol,
        priceDifferenceModelFactory: SwapPriceDifferenceModelFactoryProtocol,
        percentFormatter: LocalizableResource<NumberFormatter>
    ) {
        self.issuesViewModelFactory = issuesViewModelFactory
        self.networkViewModelFactory = networkViewModelFactory
        self.assetIconViewModelFactory = assetIconViewModelFactory

        super.init(
            balanceViewModelFactoryFacade: balanceViewModelFactoryFacade,
            priceDifferenceModelFactory: priceDifferenceModelFactory,
            priceAssetInfoFactory: priceAssetInfoFactory,
            percentFormatter: percentFormatter
        )
    }

    private static func buttonTitle(
        params: SwapIssueCheckParams,
        issues: [SwapSetupViewIssue],
        locale: Locale
    ) -> String {
        let strings = R.string(preferredLanguages: locale.rLanguages).localizable

        guard let payChainAsset = params.payChainAsset else {
            return strings.swapsSetupAssetActionSelectPay()
        }

        guard params.receiveChainAsset != nil else {
            return strings.swapsSetupAssetActionSelectReceive()
        }

        if issues.contains(.insufficientBalance) {
            return strings.swapsSetupActionNotEnoughToken(payChainAsset.asset.symbol)
        }

        if case let .failure(error) = params.quoteResult, SwapQuoteFailure(error: error) == .noRoute {
            return strings.swapsSetupActionNoRoute()
        }

        if !params.hasEnteredAmount {
            return strings.swapsSetupActionEnterAnAmount()
        }

        if params.isQuoting {
            return strings.swapsSetupActionGettingRate()
        }

        return strings.commonContinue()
    }

    private func assetViewModel(chainAsset: ChainAsset) -> SwapsAssetViewModel {
        let networkViewModel = networkViewModelFactory.createViewModel(from: chainAsset.chain)
        let assetIcon = assetIconViewModelFactory.createAssetIconViewModel(for: chainAsset.asset.icon)

        return SwapsAssetViewModel(
            symbol: chainAsset.asset.symbol,
            imageViewModel: assetIcon,
            hub: networkViewModel
        )
    }

    private func emptyPayAssetViewModel(for locale: Locale) -> EmptySwapsAssetViewModel {
        EmptySwapsAssetViewModel(
            imageViewModel: StaticImageViewModel(image: R.image.iconAddSwapAmount()!),
            title: R.string(preferredLanguages: locale.rLanguages).localizable.swapsSetupAssetPayTitle(),
            subtitle: R.string(preferredLanguages: locale.rLanguages).localizable.swapsSetupAssetSelectSubtitle()
        )
    }

    private func emptyReceiveAssetViewModel(for locale: Locale) -> EmptySwapsAssetViewModel {
        EmptySwapsAssetViewModel(
            imageViewModel: StaticImageViewModel(image: R.image.iconAddSwapAmount()!),
            title: R.string(preferredLanguages: locale.rLanguages).localizable.swapsSetupAssetReceiveTitle(),
            subtitle: R.string(preferredLanguages: locale.rLanguages).localizable.swapsSetupAssetSelectSubtitle()
        )
    }

    private static func minReceived(for quote: AssetExchangeQuote, slippage: BigRational) -> Balance {
        let slippageBoundOperations = switch quote.route.direction {
        case .sell:
            quote.metaOperations[...]
        case .buy:
            quote.metaOperations.dropFirst()
        }

        let slippageBoundSwapCount = slippageBoundOperations.filter { $0.label == .swap }.count

        let amountOut = quote.route.amountOut
        let compoundedAmountOutMin = (0 ..< slippageBoundSwapCount).reduce(amountOut) { amount, _ in
            amount.subtractOrZero(slippage.mul(value: amount))
        }

        let slippageLoss = amountOut - compoundedAmountOutMin

        return quote.commissionNetFlow().netFinalAmountOut.subtractOrZero(slippageLoss)
    }
}

extension SwapsSetupViewModelFactory: SwapsSetupViewModelFactoryProtocol {
    func buttonState(for issueParams: SwapIssueCheckParams, locale: Locale) -> ButtonState {
        let dataFullFilled = issueParams.payChainAsset != nil &&
            issueParams.receiveChainAsset != nil &&
            (issueParams.payAmount ?? 0) > 0

        let issues = issuesViewModelFactory.detectIssues(in: issueParams, locale: locale)

        return .init(
            title: .init {
                Self.buttonTitle(
                    params: issueParams,
                    issues: issues,
                    locale: $0
                )
            },
            enabled: dataFullFilled && issueParams.hasEnteredAmount && issues.isEmpty && !issueParams.isQuoting
        )
    }

    func payTitleViewModel(
        assetDisplayInfo: AssetBalanceDisplayInfo?,
        maxValue: Decimal?,
        locale: Locale
    ) -> TitleHorizontalMultiValueView.Model {
        let title = R.string(preferredLanguages: locale.rLanguages).localizable.swapsSetupAssetSelectPayTitle()

        if let assetDisplayInfo = assetDisplayInfo, let maxValue = maxValue {
            let maxValueString = balanceViewModelFactoryFacade.amountFromValue(
                targetAssetInfo: assetDisplayInfo,
                value: maxValue
            ).value(for: locale)

            return .init(
                title: title,
                subtitle:
                R.string(preferredLanguages: locale.rLanguages).localizable.swapsSetupAssetMax(),
                value: maxValueString
            )
        } else {
            return .init(
                title:
                R.string(preferredLanguages: locale.rLanguages).localizable.swapsSetupAssetSelectPayTitle(),
                subtitle: "",
                value: ""
            )
        }
    }

    func payAssetViewModel(chainAsset: ChainAsset?, locale: Locale) -> SwapAssetInputViewModel {
        chainAsset.map { .asset(assetViewModel(chainAsset: $0)) } ??
            .empty(emptyPayAssetViewModel(for: locale))
    }

    func inputPriceViewModel(
        assetDisplayInfo: AssetBalanceDisplayInfo,
        amount: Decimal?,
        priceData: PriceData?,
        locale: Locale
    ) -> String? {
        guard let priceData = priceData else {
            return nil
        }
        return balanceViewModelFactoryFacade.priceFromAmount(
            targetAssetInfo: assetDisplayInfo,
            amount: amount ?? 0,
            priceData: priceData
        ).value(for: locale)
    }

    func receiveTitleViewModel(
        assetDisplayInfo: AssetBalanceDisplayInfo?,
        balance: Balance?,
        locale: Locale
    ) -> TitleHorizontalMultiValueView.Model {
        let strings = R.string(preferredLanguages: locale.rLanguages).localizable
        let title = strings.swapsSetupAssetSelectReceiveTitle()

        guard let assetDisplayInfo, let balance else {
            return .init(title: title, subtitle: "", value: "")
        }

        let balanceString = balanceViewModelFactoryFacade.amountFromValue(
            targetAssetInfo: assetDisplayInfo,
            value: balance.decimal(assetInfo: assetDisplayInfo)
        ).value(for: locale)

        return .init(title: title, subtitle: strings.swapsSetupAssetBalance(), value: balanceString)
    }

    func slippageViewModel(
        slippage: BigRational,
        bounds: SlippageBounds,
        locale: Locale
    ) -> SwapSetupSlippageViewModel {
        let value = slippage.decimalValue
        let valueString = value.flatMap { percentFormatter.value(for: locale).stringFromDecimal($0) } ?? ""

        return SwapSetupSlippageViewModel(
            value: valueString,
            hasWarning: bounds.warning(for: value, locale: locale) != nil
        )
    }

    func minReceivedViewModel(
        for quote: AssetExchangeQuote,
        slippage: BigRational,
        chainAsset: ChainAsset,
        locale: Locale
    ) -> String {
        let assetDisplayInfo = chainAsset.assetDisplayInfo
        let minReceived = Self.minReceived(for: quote, slippage: slippage)

        return balanceViewModelFactoryFacade.amountFromValue(
            targetAssetInfo: assetDisplayInfo,
            value: minReceived.decimal(assetInfo: assetDisplayInfo),
            roundingMode: .down
        ).value(for: locale)
    }

    func receiveAssetViewModel(chainAsset: ChainAsset?, locale: Locale) -> SwapAssetInputViewModel {
        chainAsset.map { .asset(assetViewModel(chainAsset: $0)) } ??
            .empty(emptyReceiveAssetViewModel(for: locale))
    }

    func amountInputViewModel(
        chainAsset: ChainAsset,
        amount: Decimal?,
        locale: Locale
    ) -> AmountInputViewModelProtocol {
        balanceViewModelFactoryFacade.createBalanceInputViewModel(
            targetAssetInfo: chainAsset.assetDisplayInfo,
            amount: amount
        ).value(for: locale)
    }

    func amountFromValue(_ decimal: Decimal, chainAsset: ChainAsset, locale: Locale) -> String {
        balanceViewModelFactoryFacade.amountFromValue(
            targetAssetInfo: chainAsset.assetDisplayInfo,
            value: decimal
        ).value(for: locale)
    }

    func detectIssues(in model: SwapIssueCheckParams, locale: Locale) -> [SwapSetupViewIssue] {
        issuesViewModelFactory.detectIssues(in: model, locale: locale)
    }
}
