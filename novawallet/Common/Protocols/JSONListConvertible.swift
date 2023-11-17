import Foundation
import SubstrateSdk

enum JSONListConvertibleError: Error {
    case unexpectedNumberOfItems(expected: Int, actual: Int)
    case unexpectedValue(JSON)
}

protocol JSONListConvertible {
    init(jsonList: [JSON], context: [CodingUserInfoKey: Any]?) throws
}
