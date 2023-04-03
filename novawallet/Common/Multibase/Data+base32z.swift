import Foundation

extension String {
    func base32zDecodedData() -> Data? {
        let base32zAlphabet = "ybndrfg8ejkmcpqxot1uwisza345h769"
        var bits: UInt64 = 0
        var bitsRemaining = 0
        var decodedBytes = [UInt8]()

        for character in self {
            guard let value = base32zAlphabet.firstIndex(of: character) else { return nil }
            bits = (bits << 5) | UInt64(base32zAlphabet.position(value))
            bitsRemaining += 5

            if bitsRemaining >= 8 {
                let byte = UInt8(truncatingIfNeeded: bits >> (bitsRemaining - 8))
                decodedBytes.append(byte)
                bitsRemaining -= 8
            }
        }

        return Data(decodedBytes)
    }
}
