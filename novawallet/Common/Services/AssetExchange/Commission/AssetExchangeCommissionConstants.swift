import Foundation

enum AssetExchangeCommissionConstants {
    /// The advertised rate: 0.85% of the amount the user actually receives. This is the figure shown in the
    /// commission disclosure, and the one applied when grossing up a specified-out amount.
    static let rate = BigRational(numerator: 85, denominator: 10000)

    static let hydrationBeneficiaryAddress = "15ReoCRFgpGXjuaFXzGv7qaqiRrFE5uEMGVC7tBQhaWfzXh"
}

extension BigRational {
    /// The same commission re-expressed against the pool output *before* it is taken.
    ///
    /// `rate` is a fraction of the net amount, but every deduction and the on-chain transfer are computed
    /// from the gross output, so they need `n / (d + n)` rather than `n / d`. This keeps the round trip
    /// exact: `commissionIncludedIn(net + commissionToAddOnTop(net)) == commissionToAddOnTop(net)`.
    var asShareOfGross: BigRational {
        BigRational(numerator: numerator, denominator: denominator + numerator)
    }
}
