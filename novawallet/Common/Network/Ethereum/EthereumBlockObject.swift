import Foundation
import BigInt
import Core

struct EthereumBlockObject: Codable {
    struct Transaction: Codable {
        // swiftlint:disable:next nesting
        enum CodingKeys: String, CodingKey {
            case hash
            case sender = "from"
            case input
            case recepient = "to"
            case amount = "value"
        }

        @HexCodable var hash: Data
        @HexCodable var sender: AccountId
        @HexCodable var input: Data
        @OptionHexCodable var recepient: AccountId?
        @HexCodable var amount: BigUInt

        var isNativeTransfer: Bool { input.isEmpty }
    }

    let transactions: [Transaction]
    @HexCodable var timestamp: BigUInt
}
