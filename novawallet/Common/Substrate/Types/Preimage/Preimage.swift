import Foundation
import SubstrateSdk

enum Preimage {
    static var preimageForStoragePath: StorageCodingPath {
        StorageCodingPath(moduleName: "Preimage", itemName: "PreimageFor")
    }

    static var statusForStoragePath: StorageCodingPath {
        StorageCodingPath(moduleName: "Preimage", itemName: "StatusFor")
    }

    struct PreimageKey: Encodable {
        let hash: Data
        let length: UInt32

        func encode(to encoder: Encoder) throws {
            var container = encoder.unkeyedContainer()

            try container.encode(hash)
            try container.encode(StringScaleMapper(value: length))
        }
    }
}
