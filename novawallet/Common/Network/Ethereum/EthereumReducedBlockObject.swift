import Foundation
import BigInt

struct EthereumReducedBlockObject: Decodable {
    @OptionHexCodable var baseFeePerGas: BigUInt?
}
