import Foundation

extension Data {
    func base16Decoded() -> Data? {
        // Create a mutable copy of the data
        var data = self

        // Make sure the data length is a multiple of 2 (since each base-16 digit represents 4 bits)
        if data.count % 2 != 0 {
            return nil
        }

        // Create a new byte array to hold the decoded bytes
        var decodedBytes = [UInt8]()

        // Iterate through the data two bytes (16 bits) at a time
        for index in stride(from: 0, to: data.count, by: 2) {
            // Get the next two bytes as a UInt16
            let bytes = data.subdata(in: index ..< index + 2)
            let value = bytes.withUnsafeBytes { $0.load(as: UInt16.self) }

            // Extract the 16 bits as two base-16 digits (each representing 4 bits)
            let digit1 = UInt8((value >> 8) & 0xFF)
            let digit2 = UInt8(value & 0xFF)

            // Convert the base-16 digits to a byte and append it to the decoded bytes array
            decodedBytes.append((digit1 << 4) | digit2)
        }

        // Create a new Data object from the decoded bytes array
        return Data(decodedBytes)
    }
}

extension String {
    func base16DecodedData() -> Data? {
        // Convert the hex string to a Data object
        guard let hexData = self.data(using: .utf8) else {
            return nil
        }

        // Convert the hex Data object to a byte array
        var bytes = [UInt8](repeating: 0, count: hexData.count / 2)
        hexData.enumerateBytes { buffer, index, _ in
            for index in 0 ..< buffer.count {
                let byte = buffer[index]
                let index = index + index
                let nibble = byte > 64 ? byte - 55 : byte - 48
                bytes[index / 2] += (nibble << ((1 - index % 2) * 4))
            }
        }

        // Convert the byte array to a Data object
        let data = Data(bytes)
        return data
    }
}
