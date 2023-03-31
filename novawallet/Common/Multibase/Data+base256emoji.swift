import Foundation

extension String {
    func base256emojiDecodedData() -> Data? {
        // Split the string into an array of Unicode scalar values
        let scalars = unicodeScalars

        // Create a mutable array to hold the bytes
        var bytes = [UInt8]()

        // Loop through each scalar value in the array
        for scalar in scalars {
            // Check that the scalar represents a valid emoji character
            guard let codepoint = scalar.value.base256EmojiCodepoint else {
                return nil
            }

            // Append the decoded byte to the array
            bytes.append(codepoint)
        }

        // Return the decoded data
        return Data(bytes: bytes)
    }
}

extension UInt32 {
    var base256EmojiCodepoint: UInt8? {
        // Check that the value is in the range of valid codepoints
        guard self >= 0x1F600, self <= 0x1F64F else {
            return nil
        }

        // Convert the value to a byte by subtracting the base codepoint
        return UInt8(self - 0x1F600)
    }
}
