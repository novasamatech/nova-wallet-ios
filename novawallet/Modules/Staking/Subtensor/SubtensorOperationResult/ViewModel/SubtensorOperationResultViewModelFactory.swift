import Foundation
import Foundation_iOS
import BigInt

struct SubtensorResultViewContext {
    let request: SubtensorOperationResultRequest
    let catalogue: SubtensorSubnetCatalogue?
    let earnConfig: SubtensorEarnConfig?
    let remainedTime: TimeInterval
}

protocol SubtensorResultViewModelFactoryProtocol {
    func createViewModel(
        for state: SubtensorOperationResultState,
        context: SubtensorResultViewContext,
        locale: Locale
    ) -> SubtensorOperationResultViewModel
}

final class SubtensorOperationResultViewModelFactory {
    let chainAsset: ChainAsset
    let balanceViewModelFacade: BalanceViewModelFactoryFacadeProtocol
    let formatterFactory: AssetBalanceFormatterFactoryProtocol
    let assetIconViewModelFactory: AssetIconViewModelFactoryProtocol
    let subnetIconFactory: SubtensorSubnetIconFactoryProtocol
    let dateFormatter: LocalizableResource<DateFormatter>
    let percentFormatter: LocalizableResource<NumberFormatter>

    init(
        chainAsset: ChainAsset,
        priceAssetInfoFactory: PriceAssetInfoFactoryProtocol,
        formatterFactory: AssetBalanceFormatterFactoryProtocol = AssetBalanceFormatterFactory(),
        assetIconViewModelFactory: AssetIconViewModelFactoryProtocol = AssetIconViewModelFactory(),
        subnetIconFactory: SubtensorSubnetIconFactoryProtocol = SubtensorSubnetIconViewModelFactory()
    ) {
        self.chainAsset = chainAsset
        balanceViewModelFacade = BalanceViewModelFactoryFacade(priceAssetInfoFactory: priceAssetInfoFactory)
        self.formatterFactory = formatterFactory
        self.assetIconViewModelFactory = assetIconViewModelFactory
        self.subnetIconFactory = subnetIconFactory
        dateFormatter = DateFormatter.shortDateAndTime
        percentFormatter = NumberFormatter.percentSingleHalfEven.localizableResource()
    }
}

extension SubtensorOperationResultViewModelFactory {
    var taoInfo: AssetBalanceDisplayInfo {
        chainAsset.assetDisplayInfo
    }

    func alphaInfo(for context: SubtensorResultViewContext) -> AssetBalanceDisplayInfo {
        AssetBalanceDisplayInfo(
            displayPrecision: taoInfo.displayPrecision,
            assetPrecision: taoInfo.assetPrecision,
            symbol: SubtensorSubnetNaming.symbol(for: context.request.target.netuid, in: context.catalogue),
            symbolValueSeparator: taoInfo.symbolValueSeparator,
            symbolPosition: taoInfo.symbolPosition,
            icon: nil
        )
    }

    func formatAmount(_ amount: Balance, info: AssetBalanceDisplayInfo, locale: Locale) -> String {
        balanceViewModelFacade.amountFromValue(
            targetAssetInfo: info,
            value: amount.decimal(assetInfo: info)
        ).value(for: locale)
    }

    func formatTaoFiat(_ amount: Balance, prices: SubtensorOperationResultPrices, locale: Locale) -> String? {
        guard let taoPrice = prices.taoPrice else {
            return nil
        }

        return balanceViewModelFacade.balanceFromPrice(
            targetAssetInfo: taoInfo,
            amount: amount.decimal(assetInfo: taoInfo),
            priceData: taoPrice
        ).value(for: locale).price
    }

    func formatTime(_ date: Date, locale: Locale) -> String {
        dateFormatter.value(for: locale).string(from: date)
    }

    func formatTolerance(_ tolerance: BigRational, locale: Locale) -> String? {
        tolerance.decimalValue.flatMap { percentFormatter.value(for: locale).stringFromDecimal($0) }
    }

    func validatorName(for request: SubtensorOperationResultRequest) -> String {
        let display = request.validator.display

        return display.username.isEmpty ? display.address.truncated : display.username
    }

    func networkFee(
        for state: SubtensorOperationResultState,
        request: SubtensorOperationResultRequest,
        locale: Locale
    ) -> BalanceViewModelProtocol {
        let paidFee: Balance? = if case let .done(outcome, _) = state {
            outcome.networkFeePaid
        } else {
            nil
        }

        let fee = paidFee ?? request.estimatedNetworkFee.amount
        let amount = formatterFactory.createFeeTokenFormatter(for: taoInfo)
            .value(for: locale)
            .stringFromDecimal(fee.decimal(assetInfo: taoInfo)) ?? ""
        let price = formatTaoFiat(fee, prices: request.prices, locale: locale)

        guard paidFee == nil else {
            return BalanceViewModel(amount: amount, price: price)
        }

        return BalanceViewModel(amount: amount.approximatelyEqual(), price: price)
    }

    func failureReason(
        for failure: SubtensorStakingSubmissionFailure,
        holdRemaining: TimeInterval?,
        request: SubtensorOperationResultRequest,
        locale: Locale
    ) -> String {
        let strings = R.string(preferredLanguages: locale.rLanguages).localizable

        switch failure.error as? SubtensorStakingSubmissionError {
        case .slippageTooHigh, .priceLimitExceeded:
            if
                !request.target.isRoot,
                let tolerance = request.slippage.flatMap({ formatTolerance($0, locale: locale) }) {
                return strings.stakingSubtensorResultFailedPriceMovedFormat(tolerance)
            }
        case .rootStakeLocked:
            let reason = strings.stakingSubtensorResultRootLockedReason()

            guard let holdRemaining, holdRemaining > 0 else {
                return reason
            }

            let duration = holdRemaining.localizedDaysHoursOrFallbackMinutes(for: locale)

            return [reason, strings.stakingSubtensorResultTryAgainInFormat(duration)].joined(separator: " ")
        default:
            break
        }

        if let content = (failure.error as? ErrorContentConvertible)?.toErrorContent(for: locale) {
            return content.message
        }

        return strings.commonUndefinedErrorMessage()
    }

    func failureAction(
        for failure: SubtensorStakingSubmissionFailure,
        locale: Locale
    ) -> SubtensorResultActionViewModel {
        let strings = R.string(preferredLanguages: locale.rLanguages).localizable

        return failure.isRetryable
            ? SubtensorResultActionViewModel(action: .tryAgain, title: strings.commonTryAgain())
            : SubtensorResultActionViewModel(action: .close, title: strings.commonClose())
    }
}

extension SubtensorOperationResultViewModelFactory: SubtensorResultViewModelFactoryProtocol {
    func createViewModel(
        for state: SubtensorOperationResultState,
        context: SubtensorResultViewContext,
        locale: Locale
    ) -> SubtensorOperationResultViewModel {
        if context.request.target.isRoot {
            .sheet(createSheetViewModel(for: state, context: context, locale: locale))
        } else {
            .page(createPageViewModel(for: state, context: context, locale: locale))
        }
    }
}
