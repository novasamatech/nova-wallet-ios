import Foundation
import SubstrateSdk
import BigInt

extension Multistaking {
    struct ParachainStateChange {
        let stake: BigUInt?
        let shouldHaveActiveCollator: Bool
    }
}
