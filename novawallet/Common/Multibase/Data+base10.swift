import Foundation
import BigInt

extension Data {
    init?(base10Encoded input: String) {
        let leadingZeroCount = input.prefix(while: { $0 == "0" }).count

        guard let big = BigInt(input) else {
            return nil
        }
        var bytes = big.serialize().drop(while: { $0 == 0 })

        self = Array(repeating: 0, count: leadingZeroCount) + bytes
    }
}
