import Foundation

extension Data {
    func base32HexDecoded() -> Data? {
        // Create a mutable copy of the data
        var data = self

        // Remove any padding characters from the end of the data
        while data.last == 61 { // ASCII code for "="
            data.removeLast()
        }

        // Create a new byte array to hold the decoded bytes
        var decodedBytes = [UInt8]()

        // Initialize the bit buffer and bit count
        var bitBuffer: UInt64 = 0
        var bitCount: UInt8 = 0

        let base32HexDecodeTable: [Int: UInt8] = [
            48: 14, // '0' -> 14
            49: 15, // '1' -> 15
            50: 16, // '2' -> 16
            51: 17, // '3' -> 17
            52: 18, // '4' -> 18
            53: 19, // '5' -> 19
            54: 20, // '6' -> 20
            55: 21, // '7' -> 21
            56: 22, // '8' -> 22
            57: 23, // '9' -> 23
            65: 0, // 'A' -> 0
            66: 1, // 'B' -> 1
            67: 2, // 'C' -> 2
            68: 3, // 'D' -> 3
            69: 4, // 'E' -> 4
            70: 5, // 'F' -> 5
            71: 6, // 'G' -> 6
            72: 7, // 'H' -> 7
            73: 8, // 'I' -> 8
            74: 9, // 'J' -> 9
            75: 10, // 'K' -> 10
            76: 11, // 'L' -> 11
            77: 12, // 'M' -> 12
            78: 13, // 'N' -> 13
            79: 24, // 'O' -> 24
            80: 25, // 'P' -> 25
            81: 26, // 'Q' -> 26
            82: 27, // 'R' -> 27
            83: 28, // 'S' -> 28
            84: 29, // 'T' -> 29
            85: 30, // 'U' -> 30
            86: 31, // 'V' -> 31
        ]

        // Iterate through the base-32 hex characters in the data
        for character in data {
            // Convert the base-32 hex character to a 5-bit value
            guard let value = base32HexDecodeTable[Int(character.asciiValue!)] else {
                return nil // Invalid base-32 hex character
            }

            // Shift the 5-bit value into the bit buffer
            bitBuffer = (bitBuffer << 5) | UInt64(value)
            bitCount += 5

            // If the bit buffer is full (i.e., has 8 or more bits), extract a byte and append it to the decoded bytes array
            if bitCount >= 8 {
                let byte = UInt8((bitBuffer >> (bitCount - 8)) & 0xFF)
                decodedBytes.append(byte)
                bitCount -= 8
            }
        }

        // Check that the final bit count is less than 8 (i.e., there are no remaining bits in the bit buffer)
        if bitCount >= 8 {
            return nil // Invalid base-32 hex padding
        }

        // Create a new Data object from the decoded bytes array
        return Data(decodedBytes)
    }
}

extension UInt8 {
    var asciiValue: UInt32? {
        UInt32(self)
    }
}

extension String {
    func base32hexDecodedData() -> Data? {
        // Define the base32hex alphabet and padding character
        let alphabet = "0123456789ABCDEFGHIJKLMNOPQRSTUV"
        let paddingChar = "="

        // Remove any padding characters from the string
        var base32hexString = replacingOccurrences(of: paddingChar, with: "")

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
