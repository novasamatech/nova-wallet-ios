import Foundation

extension Data {
    private static let base58FlickrDecodeTable: [UInt8] = [
        // The Base58Flickr character set, in order
        0, 1, 2, 3, 4, 5, 6, 7, 8, 9,
        10, 11, 12, 13, 14, 15, 16, 17, 18, 19,
        20, 21, 22, 23, 24, 25, 26, 27, 28, 29,
        30, 31, 32, 33, 34, 35, 36, 37, 38, 39,
        40, 41, 42, 43, 44, 45, 46, 47, 49, 50,
        51, 52, 53, 54, 55, 56, 57, 58, 59, 60,
        61, 62, 63, 64, 65, 66, 67, 68, 69, 70,
        71, 72, 73, 74, 75, 76, 77, 78, 79, 80,
        81, 82, 83, 84, 85, 86, 87, 88, 89, 90,
        97, 98, 99, 100, 101, 102, 103, 104, 105, 106,
        107, 108, 109, 110, 111, 112, 113, 114, 115, 116,
        117, 118, 119, 120, 121, 122
    ]

    func base58FlickrDecoded() -> Data? {
        var decoded = [UInt8]()
        var value: UInt64 = 0
        var digits = 0

        for byte in self {
            guard let digit = Data.base58FlickrDecodeTable.firstIndex(of: byte) else {
                return nil // Invalid character
            }

            value = value * 58 + UInt64(digit)
            digits += 1

            if digits == 11 || byte == 122 {
                // Process 8 bytes at a time
                for _ in 0 ..< 8 {
                    decoded.append(UInt8(value & 0xFF))
                    value >>= 8
                }

                // Handle the last 3 bytes separately
                if byte == 122 {
                    decoded.append(UInt8(value & 0xFF))
                } else {
                    value >>= 8
                    decoded.append(UInt8(value & 0xFF))
                    value >>= 8
                    decoded.append(UInt8(value & 0xFF))
                }

                // Reset state for the next block
                value = 0
                digits = 0
            }
        }

        return Data(decoded.reversed())
    }
}

extension String {
    func base58FlickrDecodedData() -> Data? {
        // Define the base58flickr alphabet and padding character
        let alphabet = "123456789abcdefghijkmnopqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ"
        let paddingChar = "1"

        // Remove any padding characters from the string
        var base58FlickrString = self
        while base58FlickrString.hasPrefix(paddingChar) {
            base58FlickrString.remove(at: base58FlickrString.startIndex)
        }

        // Convert the base58flickr string to a byte array
        var bytes = [UInt8]()
        var value: UInt64 = 0
        var leadingZeros = 0
        for char in base58FlickrString {
            guard let charIndex = alphabet.firstIndex(of: char) else {
                return nil
            }
            value = (value * 58) + UInt64(alphabet.position(charIndex))
            if char == alphabet.first {
                leadingZeros += 1
            } else {
                for _ in 0 ..< leadingZeros {
                    bytes.append(0)
                }
                leadingZeros = 0
            }
        }
        for _ in 0 ..< leadingZeros {
            bytes.append(0)
        }
        var index = bytes.count - 1
        while value > 0 {
            let byte = UInt8(value & 0xFF)
            bytes[index] = byte
            value = value >> 8
            index -= 1
        }

        // Convert the byte array to a Data object
        let data = Data(bytes)
        return data
    }
}
