import Foundation

extension Data {
    init?(proquint input: String) {
        let consonants = "bdfghjklmnprstvz"
        let vowels = "aiou"

        let parts = input.components(separatedBy: "-")

        guard parts.count == 2 else { return nil }

        let part1 = parts[0]
        let part2 = parts[1]

        var result = UInt32(0)

        for char in part1 {
            guard let index = consonants.firstIndex(of: char) else { return nil }

            result = result * 5 + UInt32(consonants.position(index))
        }

        result <<= 16

        for char in part2 {
            guard let index = vowels.firstIndex(of: char) else { return nil }

            result += UInt32(vowels.position(index))
            result <<= 2
        }

        result >>= 2

        self = Data(bytes: &result, count: MemoryLayout<UInt32>.size)
    }
}
