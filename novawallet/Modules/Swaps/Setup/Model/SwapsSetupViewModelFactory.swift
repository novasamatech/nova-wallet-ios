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

    func receiveTitleViewModel(for locale: Locale) -> TitleHorizontalMultiValueView.Model
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
        hasIssues: Bool,
        locale: Locale
    ) -> String {
        switch (params.payChainAsset, params.receiveChainAsset) {
        case (nil, nil), (nil, _):
            return R.string.localizable.swapsSetupAssetActionSelectPay(preferredLanguages: locale.rLanguages)
        case (_, nil):
            return R.string.localizable.swapsSetupAssetActionSelectReceive(preferredLanguages: locale.rLanguages)
        default:
            if params.payAmount == nil || params.receiveAmount == nil || hasIssues {
                return R.string.localizable.swapsSetupAssetActionEnterAmount(preferredLanguages: locale.rLanguages)
            } else {
                return R.string.localizable.commonContinue(preferredLanguages: locale.rLanguages)
            }
        }
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
            title: R.string.localizable.swapsSetupAssetPayTitle(preferredLanguages: locale.rLanguages),
            subtitle: R.string.localizable.swapsSetupAssetSelectSubtitle(preferredLanguages: locale.rLanguages)
        )
    }

    private func emptyReceiveAssetViewModel(for locale: Locale) -> EmptySwapsAssetViewModel {
        EmptySwapsAssetViewModel(
            imageViewModel: StaticImageViewModel(image: R.image.iconAddSwapAmount()!),
            title: R.string.localizable.swapsSetupAssetReceiveTitle(preferredLanguages: locale.rLanguages),
            subtitle: R.string.localizable.swapsSetupAssetSelectSubtitle(preferredLanguages: locale.rLanguages)
        )
    }

    override func formatPriceDifference(amount: Decimal, locale: Locale) -> String {
        percentFormatter.value(for: locale).stringFromDecimal(amount)?.inParenthesis() ?? ""
    }
}

extension SwapsSetupViewModelFactory: SwapsSetupViewModelFactoryProtocol {
    func buttonState(for issueParams: SwapIssueCheckParams, locale: Locale) -> ButtonState {
        let dataFullFilled = issueParams.payChainAsset != nil &&
            issueParams.receiveChainAsset != nil &&
            issueParams.payAmount != nil && issueParams.receiveAmount != nil

        let hasIssues = !issuesViewModelFactory.detectIssues(in: issueParams, locale: locale).isEmpty

        return .init(
            title: .init {
                Self.buttonTitle(
                    params: issueParams,
                    hasIssues: hasIssues,
                    locale: $0
                )
            },
            enabled: dataFullFilled && !hasIssues
        )
    }

    func payTitleViewModel(
        assetDisplayInfo: AssetBalanceDisplayInfo?,
        maxValue: Decimal?,
        locale: Locale
    ) -> TitleHorizontalMultiValueView.Model {
        let title = R.string.localizable.swapsSetupAssetSelectPayTitle(
            preferredLanguages: locale.rLanguages
        )

        if let assetDisplayInfo = assetDisplayInfo, let maxValue = maxValue {
            let maxValueString = balanceViewModelFactoryFacade.amountFromValue(
                targetAssetInfo: assetDisplayInfo,
                value: maxValue
            ).value(for: locale)

            return .init(
                title: title,
                subtitle:
                R.string.localizable.swapsSetupAssetMax(
                    preferredLanguages: locale.rLanguages
                ),
                value: maxValueString
            )
        } else {
            return .init(
                title:
                R.string.localizable.swapsSetupAssetSelectPayTitle(
                    preferredLanguages: locale.rLanguages
                ),
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
        guard
            let amount = amount,
            let priceData = priceData else {
            return nil
        }
        return balanceViewModelFactoryFacade.priceFromAmount(
            targetAssetInfo: assetDisplayInfo,
            amount: amount,
            priceData: priceData
        ).value(for: locale)
    }

    func receiveTitleViewModel(for locale: Locale) -> TitleHorizontalMultiValueView.Model {
        TitleHorizontalMultiValueView.Model(
            title:
            R.string.localizable.swapsSetupAssetSelectReceiveTitle(preferredLanguages: locale.rLanguages),
            subtitle: "",
            value: ""
        )
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
