import Foundation

enum AssetExchangeCommissionConstants {
    /// 0.85%. `BigRational.mul(value:)` is `value * numerator / denominator` on `BigUInt`, i.e.
    /// exact integer arithmetic flooring toward zero, which is the required rounding direction.
    static let rate = BigRational(numerator: 85, denominator: 10_000)

    /// Nova's Hydration fee account. Mainnet SS58; there is no testnet equivalent.
    static let hydrationBeneficiaryAddress = "15ReoCRFgpGXjuaFXzGv7qaqiRrFE5uEMGVC7tBQhaWfzXh"
}
