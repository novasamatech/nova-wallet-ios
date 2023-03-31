import Foundation

extension String {
    func base64padDecodedData() -> Data? {
        let base64Chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/="
        let base64Map: [Character: UInt8] = Dictionary(uniqueKeysWithValues: base64Chars.enumerated().map { ($1, UInt8($0)) })
        let paddingChar: Character = "="

        // Remove any whitespace from the input string
        let input = filter { !$0.isWhitespace }

        // Check that the input string contains only valid base64 characters
        guard input.allSatisfy({ base64Map[$0] != nil || $0 == paddingChar }) else {
            return nil
        }

        // Convert the input string to a sequence of base64 values
        let values = input.compactMap { base64Map[$0] }

        // Calculate the number of padding characters in the input
        let paddingCount = input.filter { $0 == paddingChar }.count

        // Check that the padding is valid
        guard paddingCount == 0 || paddingCount == 1 || paddingCount == 2 else {
            return nil
        }

        // Convert the sequence of base64 values to bytes
        var bytes: [UInt8] = []
        var currentIndex = values.startIndex
        while currentIndex < values.endIndex {
            var value: UInt32 = 0
            var bits: UInt32 = 0
            for _ in 0 ..< 4 {
                if currentIndex < values.endIndex {
                    value = (value << 6) | UInt32(values[currentIndex])
                    bits += 6
                    currentIndex = values.index(after: currentIndex)
                } else {
                    value <<= 6
                    bits += 6
                }
            }
            let bytesToAdd = min(3, bits / 8)
            for currentIndex in 0 ..< bytesToAdd {
                let byte = UInt8((value >> ((2 - currentIndex) * 8)) & 0xFF)
                bytes.append(byte)
            }
        }

        return Data(bytes)
    }
}
