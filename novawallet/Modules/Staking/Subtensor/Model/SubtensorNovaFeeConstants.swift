import Foundation

enum SubtensorNovaFeeConstants {
    static let rate = BigRational(numerator: 30, denominator: 10000)
    static let beneficiaryAddress: AccountAddress? = nil
    static let feeReserve: Balance = 10_000_000
}
