import Foundation
import BigInt

extension BigUInt {
    init?(scientific: String) {
        let actualString = scientific.convertFromScientificUInt() ?? scientific

        self.init(actualString, radix: 10)
    }
}
