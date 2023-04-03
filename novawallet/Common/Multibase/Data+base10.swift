import Foundation
import BigInt

extension String {
    func base10DecodedData() -> Data? {
        let leadingZeroCount = max(prefix(while: { $0 == "0" }).count, 0)

        guard let big = BigInt(self) else {
            return nil
        }
        var bytes = big.serialize().drop(while: { $0 == 0 })

        if leadingZeroCount > 0 {
            bytes = Array(repeating: 0, count: leadingZeroCount) + bytes
        }
        return bytes
    }
}
