import Foundation

extension String {
    func base16DecodedData() -> Data? {
        // Convert the string to uppercase for case-insensitive decoding
        let uppercaseString = uppercased()

        // Convert each pair of hexadecimal characters to a byte
        var bytes = [UInt8]()
        var index = uppercaseString.startIndex
        while index < uppercaseString.endIndex {
            let nextIndex = uppercaseString.index(index, offsetBy: 2, limitedBy: uppercaseString.endIndex) ?? uppercaseString.endIndex
            let hexPair = uppercaseString[index ..< nextIndex]
            guard let byte = UInt8(hexPair, radix: 16) else {
                return nil
            }
            bytes.append(byte)
            index = nextIndex
        }

        // Convert the byte array to a Data object
        return Data(bytes)
    }
}

extension String {
    var hexadecimal: Data? {
        var data = Data(capacity: count / 2)
        var index = startIndex

        while index < endIndex {
            let nextIndex = self.index(index, offsetBy: 2, limitedBy: endIndex) ?? endIndex
            if let byte = UInt8(self[index ..< nextIndex], radix: 16) {
                data.append(byte)
            } else {
                return nil
            }
            index = nextIndex
        }

        return data
    }
}
