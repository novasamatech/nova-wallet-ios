import Foundation
import BigInt

extension String {
    func base36DecodedData() -> Data? {
        let charset = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ"
        let base = BigUInt(charset.count)
        var result = BigUInt(0)
        var power = BigUInt(1)

        let leadingZeroCount = max(prefix(while: { $0 == "0" }).count, 0)

        for char in uppercased().reversed() {
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
        return bytes
    }
}
