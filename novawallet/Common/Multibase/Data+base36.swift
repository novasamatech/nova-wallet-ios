import Foundation
import BigInt

extension Data {
    init?(base36Encoded input: String) {
        let charset = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ"
        let base = BigUInt(charset.count)
        var result = BigUInt(0)
        var power = BigUInt(1)

        let leadingZeroCount = Swift.max(input.prefix(while: { $0 == "0" }).count, 0)

        for char in input.uppercased().reversed() {
            guard let index = charset.firstIndex(of: char) else {
                return nil
            }
            result += power * BigUInt(charset.position(index))
            power *= base
        }

        var bytes = result.serialize().drop(while: { $0 == 0 })
        if leadingZeroCount > 0 {
            bytes = Array(repeating: 0, count: leadingZeroCount) + bytes
        }

        self = bytes
    }
}
