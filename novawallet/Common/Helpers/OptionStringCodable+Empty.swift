import Foundation
import SubstrateSdk

extension KeyedDecodingContainer {
    func decode<T: LosslessStringConvertible>(_ type: OptionStringCodable<T>.Type, forKey key: K) throws -> OptionStringCodable<T> {
        if let value = try decodeIfPresent(type, forKey: key) {
            return value
        }

        return OptionStringCodable(wrappedValue: nil)
    }
}
