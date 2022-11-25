import Foundation
import SubstrateSdk

extension CallMetadata {
    func isArgumentTypeOf(_ name: String, closure: (String) -> Bool) -> Bool {
        guard let argument = arguments.first(where: { $0.name == name }) else {
            return false
        }

        return closure(argument.type)
    }
}
