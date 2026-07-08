import Foundation
import SubstrateSdk

/// Reads `netuid` from an AssetModel's `typeExtras` JSON, set in nova-utils for
/// Bittensor subnet alpha assets. Format: `"typeExtras": { "netuid": 19 }`.
///
/// Returns nil when the field is absent — callers should default to 0 (root)
/// for backward compatibility with the native TAO asset that carries no extras.
enum SubtensorNetuidExtractor {
    static let typeName = "subtensor-alpha"
    static let netuidField = "netuid"

    static func extract(from asset: AssetModel) -> UInt16? {
        guard case let .dictionaryValue(dict) = asset.typeExtras else { return nil }
        guard let raw = dict[netuidField] else { return nil }

        if let uval = raw.unsignedIntValue {
            return UInt16(clamping: uval)
        }
        if let ival = raw.signedIntValue, ival >= 0 {
            return UInt16(clamping: ival)
        }
        if let str = raw.stringValue, let parsed = UInt16(str) {
            return parsed
        }
        return nil
    }
}
