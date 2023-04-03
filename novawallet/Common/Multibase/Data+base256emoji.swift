import Foundation

extension String {
    func base256emojiDecodedData() -> Data? {
        guard let data = data(using: .utf8),
              let valueUniCode = NSString(
                  data: data,
                  encoding: String.Encoding.nonLossyASCII.rawValue
              ) else {
            return nil
        }

        return valueUniCode.data(using: String.Encoding.utf8.rawValue)
    }
}

extension UInt32 {
    func toBase256() -> [UInt8] {
        // Convert the UInt32 value to a byte array in base256
        var result = [UInt8]()
        var value = self
        while value > 0 {
            let byte = UInt8(value & 0xFF)
            result.insert(byte, at: 0)
            value >>= 8
        }
        return result
    }
}
