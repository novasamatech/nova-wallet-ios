import Foundation
import SubstrateSdk
import BigInt

extension Xcm {
    struct Multilocation: Encodable {
        @StringCodable var parents: UInt8
        let interior: Xcm.Junctions
    }
}
