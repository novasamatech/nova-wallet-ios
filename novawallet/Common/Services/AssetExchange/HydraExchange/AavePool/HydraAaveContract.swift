import BigInt
import Foundation
import SubstrateSdk

extension HydraAave {
    enum ContractError: Error {
        case invalidAddress
        case invalidResponse
    }

    enum Contract {
        static let poolAddress = "0x1b02E051683b5cfaC5929C25E84adb26ECf87B38"

        private static let getReservesListSelector = "0xd1946dbc"
        private static let getReserveDataSelector = "0x35ea6a75"
        private static let abiWordHexLength = 64
        private static let addressByteLength = 20
        private static let aTokenWordIndex = 8
        private static let assetPrecompilePrefix = Data(repeating: 0, count: 15) + Data([1])

        static func getReservesListCall() -> String {
            getReservesListSelector
        }

        static func getReserveDataCall(reserve: AccountId) throws -> String {
            guard reserve.count == addressByteLength else {
                throw ContractError.invalidAddress
            }

            return getReserveDataSelector + reserve.toHex().leftPadding(
                toLength: abiWordHexLength,
                withPad: "0"
            )
        }

        static func decodeReservesList(response: String) throws -> [AccountId] {
            let normalized = normalize(response)
            let offsetWord = try word(at: 0, in: normalized)

            guard
                let offset = Int(offsetWord, radix: 16),
                offset.isMultiple(of: abiWordHexLength / 2) else {
                throw ContractError.invalidResponse
            }

            let lengthWordIndex = offset / (abiWordHexLength / 2)
            let responseWordCount = normalized.count / abiWordHexLength

            guard lengthWordIndex < responseWordCount else {
                throw ContractError.invalidResponse
            }

            let lengthWord = try word(at: lengthWordIndex, in: normalized)

            guard
                let length = Int(lengthWord, radix: 16),
                length <= responseWordCount - lengthWordIndex - 1 else {
                throw ContractError.invalidResponse
            }

            return try (0 ..< length).map { index in
                try decodeAddress(from: word(at: lengthWordIndex + index + 1, in: normalized))
            }
        }

        static func decodeATokenAddress(response: String) throws -> AccountId {
            try decodeAddress(from: word(at: aTokenWordIndex, in: normalize(response)))
        }

        static func assetId(
            for address: AccountId,
            registeredAssets: [AccountId: HydraDx.AssetId]
        ) -> HydraDx.AssetId? {
            guard address.count == addressByteLength else {
                return nil
            }

            if address.prefix(assetPrecompilePrefix.count) == assetPrecompilePrefix {
                return HydraDx.AssetId(Data(address.suffix(4)).toHex(), radix: 16)
            }

            return registeredAssets[address]
        }

        static func findAccountKey20(in value: JSON) -> AccountId? {
            switch value {
            case let .dictionaryValue(dictionary):
                if let accountKey = dictionary.first(where: {
                    $0.key.caseInsensitiveCompare("AccountKey20") == .orderedSame
                })?.value {
                    return decodeAccountKey20(from: accountKey)
                }

                return dictionary.values.lazy.compactMap(findAccountKey20).first
            case let .arrayValue(array):
                if
                    array.count == 2,
                    array[0].stringValue?.caseInsensitiveCompare("AccountKey20") == .orderedSame {
                    return decodeAccountKey20(from: array[1])
                }

                return array.lazy.compactMap(findAccountKey20).first
            default:
                return nil
            }
        }

        private static func normalize(_ value: String) -> String {
            value.hasPrefix("0x") ? String(value.dropFirst(2)).lowercased() : value.lowercased()
        }

        private static func word(at index: Int, in response: String) throws -> String {
            guard index >= 0 else {
                throw ContractError.invalidResponse
            }

            let startOffset = index * abiWordHexLength
            let endOffset = startOffset + abiWordHexLength

            guard response.count >= endOffset else {
                throw ContractError.invalidResponse
            }

            let start = response.index(response.startIndex, offsetBy: startOffset)
            let end = response.index(response.startIndex, offsetBy: endOffset)
            let result = String(response[start ..< end])

            guard result.allSatisfy(\.isHexDigit) else {
                throw ContractError.invalidResponse
            }

            return result
        }

        private static func decodeAddress(from word: String) throws -> AccountId {
            let addressHexLength = addressByteLength * 2
            let address = String(word.suffix(addressHexLength))

            guard let result = try? AccountId(hexString: address), result.count == addressByteLength else {
                throw ContractError.invalidResponse
            }

            return result
        }

        private static func decodeAccountKey20(from value: JSON) -> AccountId? {
            switch value {
            case let .stringValue(string):
                guard let result = try? AccountId(hexString: string), result.count == addressByteLength else {
                    return nil
                }

                return result
            case let .dictionaryValue(dictionary):
                if let key = dictionary.first(where: {
                    $0.key.caseInsensitiveCompare("key") == .orderedSame
                })?.value {
                    return decodeAccountKey20(from: key)
                }

                return dictionary.values.lazy.compactMap(decodeAccountKey20).first
            case let .arrayValue(array):
                let bytes = array.compactMap { item -> UInt8? in
                    if let value = item.unsignedIntValue, value <= UInt8.max {
                        return UInt8(value)
                    }

                    if let value = item.stringValue {
                        return UInt8(value)
                    }

                    return nil
                }

                if bytes.count == addressByteLength, bytes.count == array.count {
                    return Data(bytes)
                }

                return array.lazy.compactMap(decodeAccountKey20).first
            default:
                return nil
            }
        }
    }
}
