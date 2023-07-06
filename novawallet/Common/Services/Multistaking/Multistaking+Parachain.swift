import Foundation
import SubstrateSdk
import BigInt

extension Multistaking {
    struct ParachainState {
        let stake: BigUInt?
        let shouldHaveActiveCollator: Bool
    }
}
