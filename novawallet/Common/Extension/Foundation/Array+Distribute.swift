import Foundation

extension Array {
    func distributed(intoChunks chunkCount: Int) -> [[Element]] {
        guard chunkCount > 0 else { return [] }
        guard chunkCount < count else { return map { [$0] } }

        let baseSize = count / chunkCount
        let extraElements = count % chunkCount

        return stride(
            from: 0,
            to: chunkCount,
            by: 1
        ).map { chunkIndex in
            let startIndex = chunkIndex * baseSize + Swift.min(chunkIndex, extraElements)
            let endIndex = startIndex + baseSize + (chunkIndex < extraElements ? 1 : 0)

            return Array(self[startIndex ..< endIndex])
        }
    }
}
