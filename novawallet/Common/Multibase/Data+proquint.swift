import Foundation

extension Data {
    init?(proquint input: String) {
        let consonants = [UInt8]("bdfghjklmnprstvz".utf8)
        let vowels = [UInt8]("aiou".utf8)

        let parts = input.components(separatedBy: "-")

        guard parts.count == 2 else { return nil }

        let part1 = parts[0]
        let part2 = parts[1]

        var result = UInt32(0)

        for char in part1.utf8 {
            guard let index = consonants.firstIndex(of: char) else { return nil }

            result = result * 5 + UInt32(index)
        }

        result <<= 16

        for char in part2.utf8 {
            guard let index = vowels.firstIndex(of: char) else { return nil }

            result += UInt32(index)
            result <<= 2
        }

        result >>= 2

        self = Data(bytes: &result, count: MemoryLayout<UInt32>.size)
    }
}
