import Foundation

extension String {
    func base32padDecodedData() -> Data? {
        let base32Alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567"
        let paddingChar = "="
        let paddingLength = count % 8
        let chunkLength = 8
        var currentIndex = startIndex
        var result = Data()

        while currentIndex < endIndex {
            var bits: UInt64 = 0
            var bitCount: UInt8 = 0

            for _ in 0 ..< chunkLength {
                guard currentIndex < endIndex else { break }

                let char = Character(self[currentIndex].uppercased())
                currentIndex = index(after: currentIndex)

                guard let charIndex = base32Alphabet.firstIndex(of: char) else {
                    return nil
                }

                let charValue = UInt64(base32Alphabet.position(charIndex))

                bits <<= 5
                bits |= charValue
                bitCount += 5
            }

            let byteCount = bitCount / 8

            for _ in 0 ..< byteCount {
                let byte = UInt8((bits >> (bitCount - 8)) & 0xFF)
                result.append(byte)
                bitCount -= 8
            }
        }

        if paddingLength > 0 {
            let padding = String(repeating: paddingChar, count: 8 - paddingLength)
            let encodedPadding = Data(padding.utf8)
            result = result.dropLast(Int(paddingLength)) + encodedPadding
        }

        return result
    }
}
