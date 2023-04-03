import Foundation
import BigInt

extension String {
    func base58FlickrDecodedData() -> Data? {
        let alphabet = [UInt8]("123456789abcdefghijkmnopqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ".utf8)
        var answer = BigUInt(0)
        var idx = BigUInt(1)
        let byteString = [UInt8](utf8)

        for char in byteString.reversed() {
            guard let alphabetIndex = alphabet.firstIndex(of: char) else {
                return nil
            }
            answer += (idx * BigUInt(alphabetIndex))
            idx *= BigUInt(alphabet.count)
        }

        let bytes = answer.serialize()
        return Data(Array(byteString.prefix { idx in idx == alphabet[0] }) + bytes)
    }
}
