import Foundation
import BigInt

struct WalletConnectEthereumTransaction: Codable {
    let from: String

    // swiftlint:disable:next identifier_name
    let to: String?

    @OptionHexCodable var gasLimit: BigUInt?

    @OptionHexCodable var gasPrice: BigUInt?

    @OptionHexCodable var value: BigUInt?

    @OptionHexCodable var nonce: BigUInt?

    let data: String?
}
