import Foundation

extension String {
    func base32DecodedData() -> Data? {
        let alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567".utf8.map { $0 }
        let padding: UInt8 = 61
        var bits: UInt64 = 0
        var bitCount: Int = 0
        var bytes = [UInt8]()

        for char in uppercased().utf8 {
            if let index = alphabet.firstIndex(of: char) {
                bits = (bits << 5) | UInt64(index)
                bitCount += 5

                if bitCount >= 8 {
                    let byte = UInt8(truncatingIfNeeded: bits >> UInt64(bitCount - 8))
                    bytes.append(byte)
                    bitCount -= 8
                }
            } else if char == padding {
                break
            } else {
                return nil
            }
        }

        guard bitCount <= 5 else { return nil }

        return Data(bytes: bytes, count: bytes.count)
    }
}
