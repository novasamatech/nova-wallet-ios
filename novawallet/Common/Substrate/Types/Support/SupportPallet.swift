import Foundation
import SubstrateSdk

enum SupportPallet {
    struct BoundedLookup: Decodable {
        @BytesCodable var hash: Data
        @StringCodable var len: UInt32
    }

    struct BoundedLegacy: Decodable {
        @BytesCodable var hash: Data
    }

    enum Bounded<T>: Decodable where T: Decodable {
        case legacy(hash: Data)
        case inline(value: T)
        case lookup(BoundedLookup)
        case unknown

        init(from decoder: Decoder) throws {
            var container = try decoder.unkeyedContainer()
            let type = try container.decode(String.self)

            switch type {
            case "Legacy":
                let hash = try container.decode(BoundedLegacy.self).hash
                self = .legacy(hash: hash)
            case "Inline":
                let value = try container.decode(T.self)
                self = .inline(value: value)
            case "Lookup":
                let lookup = try container.decode(BoundedLookup.self)
                self = .lookup(lookup)
            default:
                self = .unknown
            }
        }
    }
}
