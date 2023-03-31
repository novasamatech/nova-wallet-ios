import Foundation

extension String {
    func base32hexDecodedData() -> Data? {
        // Define the base32hex alphabet and padding character
        let alphabet = "0123456789ABCDEFGHIJKLMNOPQRSTUV"
        let paddingChar = "="

        // Remove any padding characters from the string
        let base32hexString = replacingOccurrences(of: paddingChar, with: "").uppercased()

        // Convert the base32hex string to a byte array
        var bytes = [UInt8]()
        var bits: UInt64 = 0
        var bitCount: UInt8 = 0
        for char in base32hexString {
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
