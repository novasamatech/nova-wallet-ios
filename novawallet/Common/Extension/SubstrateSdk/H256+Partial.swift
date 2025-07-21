import Foundation
import SubstrateSdk

extension H256 {
    init(partialData: Data) {
        let data = (partialData + Data(repeating: 0, count: Self.length)).prefix(Self.length)
        self.init(value: data)
    }
}
