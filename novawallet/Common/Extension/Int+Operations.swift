import Foundation

extension Int {
    func firstDivider(from range: [Int]) -> Int? {
        range.first { self % $0 == 0 }
    }

    func quantized(by value: Int) -> Int {
        quotientAndRemainder(dividingBy: value).quotient * value
    }
}
