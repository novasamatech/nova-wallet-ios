import Foundation
import BigInt

extension Data {
    init?(base36Encoded input: String) {
        let charset = [UInt8]("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ".utf8)
        let base = BigUInt(charset.count)
        var result = BigUInt(0)
        var power = BigUInt(1)

        let leadingZeroCount = input.prefix(while: { $0 == "0" }).count

        for char in input.uppercased().utf8.reversed() {
            guard let index = charset.firstIndex(of: char) else {
                return nil
            }
            result += power * BigUInt(index)
            power *= base
        }

        let bytes = result.serialize().drop(while: { $0 == 0 })

        self = Array(repeating: 0, count: leadingZeroCount) + bytes
    }
}
