import Foundation
import SubstrateSdk
import BigInt

extension AssetConversionPallet {
    static var swapExactTokenForTokensPath: CallCodingPath {
        CallCodingPath(moduleName: AssetConversionPallet.name, callName: "swap_exact_tokens_for_tokens")
    }

    static var swapTokenForExactTokens: CallCodingPath {
        CallCodingPath(moduleName: AssetConversionPallet.name, callName: "swap_tokens_for_exact_tokens")
    }

    static func isSwap(_ callPath: CallCodingPath) -> Bool {
        [
            AssetConversionPallet.swapExactTokenForTokensPath,
            AssetConversionPallet.swapTokenForExactTokens
        ].contains(callPath)
    }

    struct SwapExactTokensForTokensCall: Codable {
        enum CodingKeys: String, CodingKey {
            case path
            case amountIn = "amount_in"
            case amountOutMin = "amount_out_min"
            case sendTo = "send_to"
            case keepAlive = "keep_alive"
        }

        let path: [AssetConversionPallet.AssetId]
        @StringCodable var amountIn: BigUInt
        @StringCodable var amountOutMin: BigUInt
        @BytesCodable var sendTo: AccountId
        let keepAlive: Bool

        func runtimeCall(for module: String) -> RuntimeCall<Self> {
            RuntimeCall(moduleName: module, callName: "swap_exact_tokens_for_tokens", args: self)
        }
    }

    struct SwapTokensForExactTokensCall: Codable {
        enum CodingKeys: String, CodingKey {
            case path
            case amountOut = "amount_out"
            case amountInMax = "amount_in_max"
            case sendTo = "send_to"
            case keepAlive = "keep_alive"
        }

        let path: [AssetConversionPallet.AssetId]
        @StringCodable var amountOut: BigUInt
        @StringCodable var amountInMax: BigUInt
        @BytesCodable var sendTo: AccountId
        let keepAlive: Bool

        func runtimeCall(for module: String) -> RuntimeCall<Self> {
            RuntimeCall(moduleName: module, callName: "swap_tokens_for_exact_tokens", args: self)
        }
    }
}
