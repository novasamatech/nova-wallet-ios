import Foundation
import SubstrateSdk

typealias AssetTypeExtras = JSON

extension AssetTypeExtras {
    private static let contractAddressField = "contractAddress"

    static func createFrom(evmContractAddress: AccountAddress) -> AssetTypeExtras {
        AssetTypeExtras.dictionaryValue(
            [
                Self.contractAddressField: JSON.stringValue(evmContractAddress)
            ]
        )
    }

    var evmContractAddress: AccountAddress? {
        // user might still have old evm type extras with string
        switch self {
        case let .dictionaryValue(dict):
            dict[Self.contractAddressField]?.stringValue
        case let .stringValue(address):
            address
        default:
            nil
        }
    }
}
