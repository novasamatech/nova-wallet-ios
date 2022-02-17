import Foundation

final class IdentityMapper: Mapping {
    typealias InputType = Data
    typealias OutputType = Data

    func map(input: InputType) -> OutputType {
        input
    }
}
