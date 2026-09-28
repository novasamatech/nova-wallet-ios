import Foundation

enum SubtensorNovaFeeConstants {
    static let rate = BigRational(numerator: 85, denominator: 10000)
    static let beneficiaryAddress: AccountAddress = "5Fn27uxkDSv4CWs7ZU35eY25ZjrtnLQdBArVCuHQH2daiE1x"
    static let historicalBeneficiaryAddresses: [AccountAddress] = []
    static let feeReserve: Balance = 10_000_000
}
