import Foundation

enum AssetExchangeCommissionConstants {
    static let rate = BigRational(numerator: 85, denominator: 10000)

    static let hydrationBeneficiaryAddress = "15ReoCRFgpGXjuaFXzGv7qaqiRrFE5uEMGVC7tBQhaWfzXh"
}

extension BigRational {
    var asShareOfGross: BigRational {
        BigRational(numerator: numerator, denominator: denominator + numerator)
    }
}
