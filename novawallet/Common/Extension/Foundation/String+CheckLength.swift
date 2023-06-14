import Foundation

extension String {
    func checkLength(min: Int, max: Int) -> StringCheckError? {
        guard count >= min, count <= max else {
            return StringCheckError.invalidLength(expected: min ... max, was: count)
        }
        return nil
    }
}

enum StringCheckError: Error, Equatable {
    case invalidLength(expected: ClosedRange<Int>, was: Int)
}
