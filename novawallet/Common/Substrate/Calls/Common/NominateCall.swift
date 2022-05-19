import Foundation
import SubstrateSdk

struct NominateCall: Codable {
    let targets: [MultiAddress]
}
