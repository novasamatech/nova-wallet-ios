import Foundation
import SubstrateSdk

extension Staking {
    struct Nomination: Codable, Equatable {
        let targets: [Data]
        @StringCodable var submittedIn: UInt32
    }
}
