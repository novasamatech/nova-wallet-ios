import Foundation
import Web3Core

enum EvmQueryMessage {
    static let method = "eth_call"

    struct Params: Encodable {
        let call: EthereumTransaction
        let block: Web3Core.BlockNumber

        func encode(to encoder: Encoder) throws {
            var unkeyedContainer = encoder.unkeyedContainer()

            try unkeyedContainer.encode(call)
            try unkeyedContainer.encode(block)
        }
    }
}
