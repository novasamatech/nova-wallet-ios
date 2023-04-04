import Foundation
import BigInt

extension Data {
    static let btcAlphabet = [UInt8]("123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz".utf8)
    static let flickrAlphabet = [UInt8]("123456789abcdefghijkmnopqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ".utf8)

    init?(base58btcEncoded input: String) {
        guard let data = Self.decodeBase58(input: input, alphabet: Self.btcAlphabet) else {
            return nil
        }
        self = data
    }

    init?(base58FlickrEncoded input: String) {
        guard let data = Self.decodeBase58(input: input, alphabet: Self.flickrAlphabet) else {
            return nil
        }
        self = data
    }

    static func decodeBase58(input: String, alphabet: [UInt8]) -> Data? {
        var answer = BigUInt(0)
        var idx = BigUInt(1)
        let byteString = [UInt8](input.utf8)

        for char in byteString.reversed() {
            guard let alphabetIndex = alphabet.firstIndex(of: char) else {
                return nil
            }
            answer += (idx * BigUInt(alphabetIndex))
            idx *= BigUInt(alphabet.count)
        }

        let bytes = answer.serialize()
        // For every leading one on the input we need to add a leading 0 on the output
        let leadingOnes = byteString.prefix(while: { value in value == alphabet[0] })
        let leadingZeros: [UInt8] = Array(repeating: 0, count: leadingOnes.count)
        return leadingZeros + bytes
    }
}
