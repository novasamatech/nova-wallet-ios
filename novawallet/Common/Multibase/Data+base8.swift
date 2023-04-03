import Foundation

extension String {
    func base8DecodedData() -> Data? {
        let paddingChar = "0"
        let paddingLength = count % 3
        var base8 = self
        if paddingLength > 0 {
            let padding = String(repeating: paddingChar, count: 3 - paddingLength)
            base8.insert(contentsOf: padding, at: base8.startIndex)
        }
        guard let data = base8.data(using: .utf8) else { return nil }
        var result = ""
        var buffer: UInt64 = 0
        var bitsLeft: UInt64 = 0
        for byte in data {
            let value: UInt64
            if byte >= 48, byte <= 55 {
                value = UInt64(byte - 48)
            } else {
                return nil
            }
            buffer <<= 3
            buffer |= value
            bitsLeft += 3
            if bitsLeft >= 8 {
                result.append(Character(UnicodeScalar(UInt8((buffer >> (bitsLeft - 8)) & 0xFF))))
                bitsLeft -= 8
            }
        }

        return result.data(using: .utf8)
    }
}
