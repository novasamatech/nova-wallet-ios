import Foundation

extension Array {
    func distribute(intoChunks chunkCount: Int) -> [[Element]] {
        guard chunkCount > 0 else { return [] }
        guard chunkCount < count else { return map { [$0] } }

        let totalElements = count
        var result = [[Element]](
            repeating: [Element](),
            count: chunkCount
        )

        let baseSize = totalElements / chunkCount
        let remainingElements = totalElements % chunkCount

        var currentIndex = 0

        (0 ..< chunkCount).forEach { index in
            let thisChunkSize = index < remainingElements ? baseSize + 1 : baseSize

            result[index] = Array(self[currentIndex ..< currentIndex + thisChunkSize])
            currentIndex += thisChunkSize
        }

        return result
    }
}
