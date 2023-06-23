import Foundation
import SubstrateSdk
import BigInt

extension Multistaking {
    struct ParachainStateChange {
        let stake: BigUInt?
        let hasSelectedCollators: Bool
        let shouldHaveActiveCollator: Bool
    }
}
