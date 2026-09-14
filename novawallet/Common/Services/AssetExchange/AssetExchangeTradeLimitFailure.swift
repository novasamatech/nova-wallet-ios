import Foundation

struct AssetExchangeTradeLimitFailure: Error, Equatable {
    let limitedAsset: ChainAsset

    let maxGivenAmount: Balance?

    let minTradingLimit: Balance?

    let direction: AssetConversion.Direction

    let isUserInputAdjustable: Bool
}

extension AssetExchangeTradeLimitFailure {
    static let headroom = BigRational.percent(of: 95)

    func suggestion() -> Balance? {
        guard let maxGivenAmount else {
            return nil
        }

        let headroomed = Self.headroom.mul(value: maxGivenAmount)

        let suggested = switch direction {
        case .sell:
            headroomed
        case .buy:
            grossUpInverse.mul(value: headroomed)
        }

        guard suggested > 0, suggested >= (minTradingLimit ?? 0) else {
            return nil
        }

        return suggested
    }

    private var grossUpInverse: BigRational {
        let rate = AssetExchangeCommissionConstants.rate

        return BigRational(
            numerator: rate.denominator,
            denominator: rate.denominator + rate.numerator
        )
    }
}
