import Foundation

extension Int {
    func firstDivider(from range: [Int]) -> Int? {
        range.first { self % $0 == 0 }
    }

    func quantized(by value: Int) -> Int {
        quotientAndRemainder(dividingBy: value).quotient * value
    }

    func normalized(by value: Int) -> Int {
        (360 - quantized(by: value) + 90) % 360
    }
}
