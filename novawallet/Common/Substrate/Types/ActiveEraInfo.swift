import Foundation
import SubstrateSdk

struct ActiveEraInfo: Codable, Equatable {
    @StringCodable var index: EraIndex
}
