import Foundation
import BigInt
import SubstrateSdk

enum HydraConstants {
    static let novaReferralCode = "NOVA"

    // Nova swap fee: 0.85% of output, taken as a transfer in the batch
    static let novaSwapFeeNumerator: BigUInt = 85
    static let novaSwapFeeDenominator: BigUInt = 10000
    static let novaSwapFeePercentDisplay = "0.85"

    // Fee recipient account on Hydration.
    // SS58: 15ReoCRFgpGXjuaFXzGv7qaqiRrFE5uEMGVC7tBQhaWfzXh
    // Hex:  035ff76d86ca67ef0499f8597101aab0e6ad894a805cd93a51409bd6d71a8841
    static let novaFeeAccountId: AccountId = Data([
        0x03, 0x5F, 0xF7, 0x6D, 0x86, 0xCA, 0x67, 0xEF,
        0x04, 0x99, 0xF8, 0x59, 0x71, 0x01, 0xAA, 0xB0,
        0xE6, 0xAD, 0x89, 0x4A, 0x80, 0x5C, 0xD9, 0x3A,
        0x51, 0x40, 0x9B, 0xD6, 0xD7, 0x1A, 0x88, 0x41
    ])

    static func novaSwapFeeAmount(from amountOut: BigUInt) -> BigUInt {
        amountOut * novaSwapFeeNumerator / novaSwapFeeDenominator
    }

    static func amountOutAfterNovaFee(_ amountOut: BigUInt) -> BigUInt {
        amountOut - novaSwapFeeAmount(from: amountOut)
    }
}
