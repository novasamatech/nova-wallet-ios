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
        // For every leading one on the input we need to add a leading 0 on the output
        let leadingOnes = byteString.prefix(while: { value in value == alphabet[0] })
        let leadingZeros: [UInt8] = Array(repeating: 0, count: leadingOnes.count)
        return leadingZeros + bytes
    }
}
