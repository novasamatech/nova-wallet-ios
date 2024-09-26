import Foundation
import SubstrateSdk
import BigInt

extension Xcm {
    struct Multilocation: Codable {
        @StringCodable var parents: UInt8
        let interior: Xcm.JunctionsV2
    }
}
