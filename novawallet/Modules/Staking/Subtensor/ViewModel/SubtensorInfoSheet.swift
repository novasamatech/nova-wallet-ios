import Foundation
import Foundation_iOS

enum SubtensorInfoSheet: Equatable {
    case swapRate(SubtensorTradeDirection, subnetName: String)
    case slippage(BigRational, canEdit: Bool)
    case validator
    case networkFee(SubtensorTradeDirection)
    case account(address: AccountAddress, chain: ChainModel)
    case totalStaked(isRoot: Bool)
    case validatorTake
    case avgBuyPrice(symbol: String, subnetName: String)
    case youWillEarn
}

struct SubtensorInfoSheetText {
    let title: LocalizableResource<String>
    let details: LocalizableResource<String>
}

extension SubtensorInfoSheet {
    var text: SubtensorInfoSheetText? {
        switch self {
        case let .swapRate(direction, subnetName):
            return Self.swapRateText(for: direction, subnetName: subnetName)
        case let .slippage(tolerance, canEdit):
            return Self.slippageText(for: tolerance, canEdit: canEdit)
        case .validator:
            return Self.validatorText()
        case let .networkFee(direction):
            return Self.networkFeeText(for: direction)
        case .account:
            return nil
        case let .totalStaked(isRoot):
            return Self.totalStakedText(isRoot: isRoot)
        case .validatorTake:
            return Self.validatorTakeText()
        case let .avgBuyPrice(symbol, subnetName):
            return Self.avgBuyPriceText(for: symbol, subnetName: subnetName)
        case .youWillEarn:
            return Self.youWillEarnText()
        }
    }
}

private extension SubtensorInfoSheet {
    static func swapRateText(
        for direction: SubtensorTradeDirection,
        subnetName: String
    ) -> SubtensorInfoSheetText {
        let percentFormatter = NumberFormatter.percentSingleHalfEven.localizableResource()

        return SubtensorInfoSheetText(
            title: LocalizableResource { locale in
                R.string(preferredLanguages: locale.rLanguages).localizable.stakingSubtensorUiSwapRate()
            },
            details: LocalizableResource { locale in
                let feeRate = SwapBaseViewModelFactory.commissionPercent(
                    rate: SubtensorNovaFeeConstants.rate,
                    percentFormatter: percentFormatter,
                    locale: locale
                )

                let strings = R.string(preferredLanguages: locale.rLanguages).localizable

                switch direction {
                case .buy:
                    return strings.stakingSubtensorInfoSwapRateBuy(subnetName, feeRate)
                case .sell:
                    return strings.stakingSubtensorInfoSwapRateSell(subnetName, feeRate)
                }
            }
        )
    }

    static func slippageText(for tolerance: BigRational, canEdit: Bool) -> SubtensorInfoSheetText {
        let percentFormatter = NumberFormatter.percentSingleHalfEven.localizableResource()

        return SubtensorInfoSheetText(
            title: LocalizableResource { locale in
                R.string(preferredLanguages: locale.rLanguages).localizable.stakingSubtensorInfoSlippageTitle()
            },
            details: LocalizableResource { locale in
                let strings = R.string(preferredLanguages: locale.rLanguages).localizable

                let toleranceString = tolerance.decimalValue.flatMap {
                    percentFormatter.value(for: locale).stringFromDecimal($0)
                } ?? strings.stakingSubtensorUiValueUnknown()

                return canEdit
                    ? strings.stakingSubtensorInfoSlippage(toleranceString)
                    : strings.stakingSubtensorInfoSlippageFixed(toleranceString)
            }
        )
    }

    static func validatorText() -> SubtensorInfoSheetText {
        SubtensorInfoSheetText(
            title: LocalizableResource { locale in
                R.string(preferredLanguages: locale.rLanguages).localizable.stakingCommonValidator()
            },
            details: LocalizableResource { locale in
                R.string(preferredLanguages: locale.rLanguages).localizable.stakingSubtensorInfoValidator()
            }
        )
    }

    static func networkFeeText(for direction: SubtensorTradeDirection) -> SubtensorInfoSheetText {
        SubtensorInfoSheetText(
            title: LocalizableResource { locale in
                R.string(preferredLanguages: locale.rLanguages).localizable.commonNetworkFee()
            },
            details: LocalizableResource { locale in
                let strings = R.string(preferredLanguages: locale.rLanguages).localizable

                switch direction {
                case .buy:
                    return strings.stakingSubtensorInfoNetworkFeeBuy()
                case .sell:
                    return strings.stakingSubtensorInfoNetworkFeeSell()
                }
            }
        )
    }

    static func totalStakedText(isRoot: Bool) -> SubtensorInfoSheetText {
        SubtensorInfoSheetText(
            title: LocalizableResource { locale in
                let strings = R.string(preferredLanguages: locale.rLanguages).localizable

                return isRoot
                    ? strings.stakingSubtensorUiValidatorInfoStakedRoot()
                    : strings.stakingSubtensorUiValidatorInfoStakedSubnet()
            },
            details: LocalizableResource { locale in
                let strings = R.string(preferredLanguages: locale.rLanguages).localizable

                return isRoot
                    ? strings.stakingSubtensorInfoStakedRoot()
                    : strings.stakingSubtensorInfoStakedSubnet()
            }
        )
    }

    static func validatorTakeText() -> SubtensorInfoSheetText {
        SubtensorInfoSheetText(
            title: LocalizableResource { locale in
                R.string(preferredLanguages: locale.rLanguages).localizable.stakingSubtensorUiValidatorInfoTake()
            },
            details: LocalizableResource { locale in
                R.string(preferredLanguages: locale.rLanguages).localizable.stakingSubtensorInfoValidatorTake()
            }
        )
    }

    static func avgBuyPriceText(for symbol: String, subnetName: String) -> SubtensorInfoSheetText {
        SubtensorInfoSheetText(
            title: LocalizableResource { locale in
                R.string(preferredLanguages: locale.rLanguages).localizable.stakingSubtensorUiAvgBuyPrice()
            },
            details: LocalizableResource { locale in
                R.string(preferredLanguages: locale.rLanguages).localizable.stakingSubtensorInfoAvgBuyPrice(
                    symbol,
                    subnetName
                )
            }
        )
    }

    static func youWillEarnText() -> SubtensorInfoSheetText {
        SubtensorInfoSheetText(
            title: LocalizableResource { locale in
                R.string(preferredLanguages: locale.rLanguages).localizable.stakingSubtensorUiYouWillEarn()
            },
            details: LocalizableResource { locale in
                R.string(preferredLanguages: locale.rLanguages).localizable.stakingSubtensorInfoYouWillEarn()
            }
        )
    }
}
