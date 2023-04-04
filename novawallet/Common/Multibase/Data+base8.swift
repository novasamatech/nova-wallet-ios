import Foundation

extension Data {
    init?(base8Encoded input: String) {
        guard let data = input.data(using: .utf8) else {
            return nil
        }
        guard data.allSatisfy({
            $0 >= 48 && $0 <= 55
        }) else {
            return nil
        }
        var result = Data()
        var buffer: UInt64 = 0
        var bitsLeft: UInt64 = 0

        for byte in data {
            buffer <<= 3
            buffer |= UInt64(byte - 48)
            bitsLeft += 3
            if bitsLeft >= 8 {
                result.append(UInt8((buffer >> (bitsLeft - 8)) & 0xFF))
                bitsLeft -= 8
            }
        }

        self = result
    }
}
