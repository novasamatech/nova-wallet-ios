import Foundation

extension String {
    private static let base32Alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567="

    func base32padDecodedData() -> Data? {
        // Check that the number of characters is a multiple of 8
        guard count % 8 == 0 else {
            return nil
        }

        // Convert the string to a sequence of base32 characters
        let base32Chars = uppercased().filter { char in
            // Ignore any invalid characters
            guard let index = String.base32Alphabet.firstIndex(of: char) else {
                return false
            }
            // Ignore padding characters
            return index != String.base32Alphabet.index(of: "=")!
        }

        // Decode the base32 data
        var data = Data()
        var bits = UInt64()
        var bitsRemaining = 0
        for char in base32Chars {
            guard let index = String.base32Alphabet.firstIndex(of: char) else {
                return nil
            }
            let value = UInt64(String.base32Alphabet.position(index))
            bits <<= 5
            bits |= value
            bitsRemaining += 5
            if bitsRemaining >= 8 {
                let byte = UInt8((bits >> (bitsRemaining - 8)) & 0xFF)
                data.append(byte)
                bitsRemaining -= 8
            }
        }

        return data
    }
}
