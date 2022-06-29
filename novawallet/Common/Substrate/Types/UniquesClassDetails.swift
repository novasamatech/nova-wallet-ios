import Foundation
import SubstrateSdk

struct UniquesClassDetails: Codable {
    @StringCodable var items: UInt32
    let issuer: AccountId
}
