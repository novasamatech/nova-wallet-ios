import Foundation

extension Data {
    init?(base16Encoded input: String) {
        // Convert the string to uppercase for case-insensitive decoding
        let uppercaseString = input.uppercased()

        // Convert each pair of hexadecimal characters to a byte
        var bytes = [UInt8]()
        var index = uppercaseString.startIndex
        while index < uppercaseString.endIndex {
            let nextIndex = uppercaseString.index(
                index,
                offsetBy: 2,
                limitedBy: uppercaseString.endIndex
            )
                ?? uppercaseString.endIndex

            let hexPair = uppercaseString[index ..< nextIndex]
            guard let byte = UInt8(hexPair, radix: 16) else {
                return nil
            }
            bytes.append(byte)
            index = nextIndex
        }

        // Convert the byte array to a Data object
        self = Data(bytes)
    }
}
