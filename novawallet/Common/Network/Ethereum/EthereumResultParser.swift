import Foundation
import SubstrateSdk
import Web3Core
import BigInt

enum EthereumRpcResultParser {
    static func parseStringOrNil(from result: Result<JSON, Error>) -> String? {
        let optHexString = (try? result.get())?.stringValue
        return optHexString.flatMap { hexString in
            guard let data = try? Data(hexString: hexString) else {
                return nil
            }

            let (stringValue, _) = ABIDecoder.decodeSingleType(type: .string, data: data)

            return stringValue as? String
        }
    }

    static func parseUnsignedIntOrNil(from result: Result<JSON, Error>, bits: UInt64) -> BigUInt? {
        let optHexString = (try? result.get())?.stringValue

        return optHexString.flatMap { hexString in
            guard let data = try? Data(hexString: hexString) else {
                return nil
            }

            let (value, _) = ABIDecoder.decodeSingleType(type: .uint(bits: bits), data: data)

            return value as? BigUInt
        }
    }
}
