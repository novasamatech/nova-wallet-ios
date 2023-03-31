import Foundation

extension String {
    func base32DecodedData() -> Data? {
        // Define the base32 alphabet and padding character
        let alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567"
        let paddingChar = "="

        // Remove any padding characters from the string
        var base32String = replacingOccurrences(of: paddingChar, with: "")

        // Convert the base32 string to a byte array
        var bytes = [UInt8]()
        var bits: UInt64 = 0
        var bitCount: UInt8 = 0
        for char in base32String {
            guard let charIndex = alphabet.firstIndex(of: char) else {
                return nil
            }
            bits = (bits << 5) + UInt64(alphabet.position(charIndex))
            bitCount += 5
            if bitCount >= 8 {
                let shift = bitCount - 8
                let byte = UInt8((bits >> shift) & 0xFF)
                bytes.append(byte)
                bitCount -= 8
            }
        }

        // Convert the byte array to a Data object
        let data = Data(bytes)
        return data
    }
}
