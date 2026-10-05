import Foundation

enum SubtensorNovaFeeConstants {
    static let rate = BigRational(numerator: 85, denominator: 10000)
    static let beneficiaryAddress: AccountAddress = "5EAjYyJ8JaxyvHTSNuFp8fqjerTETjqhoM7MdZux2Ehzjxdq"
    static let historicalBeneficiaryAddresses: [AccountAddress] = []
    static let feeReserve: Balance = 10_000_000
}
