import Foundation
import SubstrateSdk

extension XcmV4 {
    struct Multilocation: Codable {
        @StringCodable var parents: UInt8
        let interior: XcmV4.Junctions
    }
}
