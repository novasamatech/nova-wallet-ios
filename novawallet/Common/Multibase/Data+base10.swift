import Foundation
import BigInt

extension Data {
    init?(base10Encoded input: String) {
        let leadingZeroCount = Swift.max(input.prefix(while: { $0 == "0" }).count, 0)

        guard let big = BigInt(input) else {
            return nil
        }
        var bytes = big.serialize().drop(while: { $0 == 0 })

        if leadingZeroCount > 0 {
            bytes = Array(repeating: 0, count: leadingZeroCount) + bytes
        }

        self = bytes
    }
}
