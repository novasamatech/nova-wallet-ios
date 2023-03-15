import Foundation
import SubstrateSdk

extension CallMetadata {
    func isArgumentTypeOf(_ name: String, closure: (String) -> Bool) -> Bool {
        mapArgumentTypeOf(name, closure: { closure($0) }, defaultValue: false)
    }

    func mapArgumentTypeOf<T>(_ name: String, closure: (String) throws -> T, defaultValue: T) rethrows -> T {
        guard let argument = arguments.first(where: { $0.name == name }) else {
            return defaultValue
        }

        return try closure(argument.type)
    }
}
