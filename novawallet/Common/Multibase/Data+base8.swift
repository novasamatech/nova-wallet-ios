import Foundation

extension Data {
    func base8Decoded() -> Data? {
        // Create a mutable copy of the data
        var data = self

        // Make sure the data length is a multiple of 3 (since each base-8 digit represents 3 bits)
        if data.count % 3 != 0 {
            return nil
        }

        // Create a new byte array to hold the decoded bytes
        var decodedBytes = [UInt8]()

        // Iterate through the data three bytes (24 bits) at a time
        for index in stride(from: 0, to: data.count, by: 3) {
            // Get the next three bytes as a UInt32
            let bytes = data.subdata(in: index ..< index + 3)
            let value = bytes.withUnsafeBytes { $0.load(as: UInt32.self) }

            // Extract the 24 bits as three base-8 digits (each representing 3 bits)
            let digit1 = UInt8((value >> 18) & 0x07)
            let digit2 = UInt8((value >> 15) & 0x07)
            let digit3 = UInt8((value >> 12) & 0x07)
            let digit4 = UInt8((value >> 9) & 0x07)
            let digit5 = UInt8((value >> 6) & 0x07)
            let digit6 = UInt8((value >> 3) & 0x07)
            let digit7 = UInt8(value & 0x07)

            // Convert the base-8 digits to bytes and append them to the decoded bytes array
            decodedBytes.append((digit1 << 5) | (digit2 << 2) | (digit3 >> 1))
            decodedBytes.append((digit3 << 7) | (digit4 << 4) | (digit5 << 1) | (digit6 >> 2))
            decodedBytes.append((digit6 << 6) | digit7)
        }

        // Create a new Data object from the decoded bytes array
        return Data(decodedBytes)
    }
}

extension String {
    func base8DecodedData() -> Data? {
        guard count % 3 == 0 else {
            return nil
        }

        var bytes = [UInt8]()

        var index = startIndex
        while index < endIndex {
            let substring = self[index ..< self.index(index, offsetBy: 3)]
            guard let byte = UInt8(substring, radix: 8) else {
                return nil
            }
            bytes.append(byte)
            index = self.index(index, offsetBy: 3)
        }

        return Data(bytes)
    }
}
