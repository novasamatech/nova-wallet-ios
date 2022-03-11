import Foundation
import SubstrateSdk

struct UniquesClassDetails: Codable {
    @StringCodable var instances: UInt32
    let issuer: AccountId
}
