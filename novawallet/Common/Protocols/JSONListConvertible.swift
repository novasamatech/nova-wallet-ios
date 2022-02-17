import Foundation
import SubstrateSdk

protocol JSONListConvertible {
    init(jsonList: [JSON]) throws
}
