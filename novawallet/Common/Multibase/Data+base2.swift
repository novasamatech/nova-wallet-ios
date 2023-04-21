import Foundation

extension Data {
    init?(base2Encoded input: String) {
        guard input.count % 8 == 0 else {
            return nil
        }

        var bytes = [UInt8]()

        var index = input.startIndex

        while index < input.endIndex {
            let nextIndex = input.index(index, offsetBy: 8)
            let substring = input[index ..< nextIndex]
            guard let byte = UInt8(substring, radix: 2) else {
                return nil
            }
            bytes.append(byte)
            index = nextIndex
        }

        self = Data(bytes)
    }
}
