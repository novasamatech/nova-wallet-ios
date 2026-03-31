import Foundation
import BigInt
import SubstrateSdk

enum HydraConstants {
    static let novaReferralCode = "NOVA"

    // Nova swap fee: 0.85% of output, taken as a transfer in the batch
    static let novaSwapFeeNumerator: BigUInt = 85
    static let novaSwapFeeDenominator: BigUInt = 10000
    static let novaSwapFeePercentDisplay = "0.85"

    // Fee recipient account on Hydration (SS58: 15ReoCRFgpGXjuaFXzGv7qaqiRrFE5uEMGVC7tBQhaWfzXh)
    // swiftlint:disable:next force_try
    static let novaFeeAccountId: AccountId = try! Data(
        hexString: "035ff76d86ca67ef0499f8597101aab0e6ad894a805cd93a51409bd6d71a8841"
    )

    static func novaSwapFeeAmount(from amountOut: BigUInt) -> BigUInt {
        amountOut * novaSwapFeeNumerator / novaSwapFeeDenominator
    }

    static func amountOutAfterNovaFee(_ amountOut: BigUInt) -> BigUInt {
        amountOut - novaSwapFeeAmount(from: amountOut)
    }
}
