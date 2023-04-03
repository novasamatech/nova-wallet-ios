import Foundation

extension String {
    func base256emojiDecodedData() -> Data? {
        let paddingChar = "🔥"
        let paddingLength = count % 4
        var base1024 = self
        if paddingLength > 0 {
            let padding = String(repeating: paddingChar, count: 4 - paddingLength)
            base1024.insert(contentsOf: padding, at: base1024.startIndex)
        }
        var bytes = [UInt8]()
        var buffer: UInt64 = 0
        var bitsLeft: UInt8 = 0
        for scalar in base1024.unicodeScalars {
            guard let value = scalar.base1024Value() else { return nil }
            buffer <<= 10
            buffer |= UInt64(value)
            bitsLeft += 10
            if bitsLeft >= 24 {
                bytes.append(UInt8((buffer >> 16) & 0xFF))
                bytes.append(UInt8((buffer >> 8) & 0xFF))
                bytes.append(UInt8(buffer & 0xFF))
                bitsLeft -= 24
            }
        }
        return Data(bytes)
    }
}

extension UnicodeScalar {
    func base1024Value() -> UInt32? {
        value - 0xF000
    }
}
