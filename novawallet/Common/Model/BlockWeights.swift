import Foundation
import SubstrateSdk

struct BlockWeights: Decodable {
    @StringCodable var maxBlock: UInt64
}
