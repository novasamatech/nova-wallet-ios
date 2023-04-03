import Foundation

extension String {
    func base32hexPadDecodedData() -> Data? {
        let base32Alphabet = "0123456789ABCDEFGHIJKLMNOPQRSTUV"
        let paddingChar: Character = "="

        var bits = ""
        var paddingCount = 0

        for char in uppercased().replacingOccurrences(of: String(paddingChar), with: "") {
            guard let currentIndex = base32Alphabet.firstIndex(of: char) else {
                // Invalid character
                return nil
            }

            let binary = String(base32Alphabet.position(currentIndex), radix: 2)
            let paddedBinary = String(repeating: "0", count: 5 - binary.count) + binary

            bits += paddedBinary

            if char == paddingChar {
                paddingCount += 1
            }
        }

        // Remove padding bits
        if paddingCount > 0 {
            let lastPaddingIndex = bits.index(bits.endIndex, offsetBy: -8 * paddingCount)
            bits = String(bits[..<lastPaddingIndex])
        }

        // Convert bits to data
        var data = Data()
        for bit in 0 ..< bits.count / 8 {
            let start = bits.index(bits.startIndex, offsetBy: bit * 8)
            let end = bits.index(start, offsetBy: 8)
            let byte = UInt8(bits[start ..< end], radix: 2)!
            data.append(byte)
        }

        return data
    }
}
