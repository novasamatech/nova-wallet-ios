import Foundation
import keccak
import IrohaCrypto

enum EthereumPubKeyToAddressError: Error {
    case invalidPublicKey
    case invalidPrefix
}

// TODO: Move to library
extension Data {
    func ethereumAddressFromPublicKey() throws -> Data {
        let uncompressedKey: Data

        if count == SECPublicKey.uncompressedLength() {
            uncompressedKey = self
        } else if count == SECPublicKey.length() {
            let compressedPublicKey = try SECPublicKey(rawData: self)
            uncompressedKey = compressedPublicKey.uncompressed()
        } else {
            throw EthereumPubKeyToAddressError.invalidPublicKey
        }

        guard uncompressedKey[0] == 4 else {
            throw EthereumPubKeyToAddressError.invalidPrefix
        }

        return try uncompressedKey.dropFirst().keccak256().suffix(20)
    }
}
