import Foundation
import Foundation_iOS

enum SubtensorInfoSheet: Equatable {
    case swapRate(SubtensorTradeDirection, subnetName: String)
    case slippage(BigRational, canEdit: Bool)
    case validator
    case networkFee(SubtensorTradeDirection)
    case totalStaked(isRoot: Bool)
    case validatorTake
    case avgBuyPrice(symbol: String, subnetName: String)
    case youWillEarn
}

extension SubtensorInfoSheet {
    var title: LocalizableResource<String> {
        LocalizableResource { locale in
            let strings = R.string(preferredLanguages: locale.rLanguages).localizable

            switch self {
            case .swapRate:
                return strings.stakingSubtensorUiSwapRate()
            case .slippage:
                return strings.stakingSubtensorInfoSlippageTitle()
            case .validator:
                return strings.stakingCommonValidator()
            case .networkFee:
                return strings.commonNetworkFee()
            case .totalStaked:
                return strings.stakingMainTotalStakedTitle()
            case .validatorTake:
                return strings.stakingSubtensorUiValidatorInfoTake()
            case .avgBuyPrice:
                return strings.stakingSubtensorUiAvgBuyPrice()
            case .youWillEarn:
                return strings.stakingSubtensorUiYouWillEarn()
            }
        }
    }

    var details: LocalizableResource<String> {
        LocalizableResource { locale in
            let strings = R.string(preferredLanguages: locale.rLanguages).localizable
            let percentFormatter = NumberFormatter.percentSingleHalfEven.localizableResource()

            switch self {
            case let .swapRate(direction, subnetName):
                let feeRate = SwapBaseViewModelFactory.commissionPercent(
                    rate: SubtensorNovaFeeRateStore.shared.rate,
                    percentFormatter: percentFormatter,
                    locale: locale
                )

                switch direction {
                case .buy:
                    return strings.stakingSubtensorInfoSwapRateBuy(subnetName, feeRate)
                case .sell:
                    return strings.stakingSubtensorInfoSwapRateSell(subnetName, feeRate)
                }
            case let .slippage(tolerance, canEdit):
                let toleranceString = tolerance.decimalValue.flatMap {
                    percentFormatter.value(for: locale).stringFromDecimal($0)
                } ?? strings.stakingSubtensorUiValueUnknown()

                return canEdit
                    ? strings.stakingSubtensorInfoSlippage(toleranceString)
                    : strings.stakingSubtensorInfoSlippageFixed(toleranceString)
            case .validator:
                return strings.stakingSubtensorInfoValidator()
            case let .networkFee(direction):
                switch direction {
                case .buy:
                    return strings.stakingSubtensorInfoNetworkFeeBuy()
                case .sell:
                    return strings.stakingSubtensorInfoNetworkFeeSell()
                }
            case let .totalStaked(isRoot):
                return isRoot
                    ? strings.stakingSubtensorInfoStakedRoot()
                    : strings.stakingSubtensorInfoStakedSubnet()
            case .validatorTake:
                return strings.stakingSubtensorInfoValidatorTake()
            case let .avgBuyPrice(symbol, subnetName):
                return strings.stakingSubtensorInfoAvgBuyPrice(symbol, subnetName)
            case .youWillEarn:
                return strings.stakingSubtensorInfoYouWillEarn()
            }
        }
    }
}
