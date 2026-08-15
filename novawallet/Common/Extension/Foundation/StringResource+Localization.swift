import Foundation
import RswiftResources

extension StringResource {
    func localizedOrDevelopmentValue() -> String {
        let value = callAsFunction()

        guard value == key.description else {
            return value
        }

        return developmentValue ?? value
    }
}

extension StringResource2 {
    func localizedOrDevelopmentValue(_ arg1: Arg1, _ arg2: Arg2) -> String {
        let value = callAsFunction(arg1, arg2)

        guard value == key.description else {
            return value
        }

        return formattedDevelopmentValue(arg1, arg2) ?? value
    }

    func formattedDevelopmentValue(_ arg1: Arg1, _ arg2: Arg2) -> String? {
        developmentValue.map { String(format: $0, arguments: [arg1, arg2]) }
    }
}
