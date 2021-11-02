import Foundation
import SubstrateSdk

struct Nomination: Codable, Equatable {
    let targets: [Data]
    @StringCodable var submittedIn: UInt32
}
