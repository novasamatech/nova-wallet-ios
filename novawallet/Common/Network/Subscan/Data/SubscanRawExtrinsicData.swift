import Foundation
import SubstrateSdk

struct SubscanRawExtrinsicsData: Decodable {
    let count: Int
    let extrinsics: [JSON]?
}
