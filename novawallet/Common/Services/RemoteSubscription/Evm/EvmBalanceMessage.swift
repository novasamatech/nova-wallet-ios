import Foundation
import Web3Core

enum EvmBalanceMessage {
    static let method = "eth_getBalance"

    struct Params: Encodable {
        let holder: AccountAddress
        let block: Web3Core.BlockNumber

        func encode(to encoder: Encoder) throws {
            var unkeyedContainer = encoder.unkeyedContainer()

            try unkeyedContainer.encode(holder)
            try unkeyedContainer.encode(block)
        }
    }
}
