import Foundation
import BigInt

extension String {
    func base10DecodedData() -> Data? {
        guard let big = BigInt("00" + self) else {
            return nil
        }
        let bytes = big.serialize().drop(while: { $0 == 0 })

        return Data(bytes)
    }
}
