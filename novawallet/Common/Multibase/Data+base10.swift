import Foundation

extension Data {
    func base10Decoded() -> Data? {
        // Convert the data to a string
        guard let string = String(data: self, encoding: .utf8) else {
            return nil
        }

        // Convert the string to an array of decimal values
        let decimalValues = string.components(separatedBy: .newlines).compactMap { Int($0) }

        // Convert the decimal values to bytes
        var decodedBytes = [UInt8]()
        for decimalValue in decimalValues {
            decodedBytes.append(UInt8(decimalValue))
        }

        // Create a new Data object from the decoded bytes array
        return Data(decodedBytes)
    }
}

extension String {
    func base10DecodedData() -> Data? {
        // Convert the decimal string to an integer
        guard let decimal = Int(self) else {
            return nil
        }

        // Convert the decimal integer to a byte array
        var bytes: [UInt8] = []
        var mutableDecimal = decimal
        while mutableDecimal > 0 {
            let remainder = mutableDecimal % 256
            bytes.insert(UInt8(remainder), at: 0)
            mutableDecimal /= 256
        }

        // Convert the byte array to a Data object
        let data = Data(bytes)
        return data
    }
}
