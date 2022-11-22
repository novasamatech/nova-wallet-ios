import Foundation

extension Data {
    func fillRightWithZeros(ifLess size: Int) -> Data {
        guard count < size else {
            return self
        }

        let neededZeros = size - count

        return self + Data(repeating: 0, count: neededZeros)
    }
}
