import Foundation
import SubstrateSdk

extension XcmV3 {
    struct Multilocation: Equatable, Codable {
        @StringCodable var parents: UInt8
        let interior: XcmV3.Junctions
    }
}
