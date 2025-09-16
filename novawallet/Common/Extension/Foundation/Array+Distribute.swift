import Foundation

extension Array {
    func distributed(intoChunks chunkCount: Int) -> [[Element]] {
        guard chunkCount > 0 else { return [] }
        guard chunkCount < count else { return map { [$0] } }

        let extraElements = count % chunkCount

        let baseChunkLen = count / chunkCount
        let maxChunkLen = (count / chunkCount) + 1

        return (0 ..< chunkCount).map { chunkIndex in
            let offset = Swift.min(chunkIndex, extraElements) * maxChunkLen +
                Swift.max(0, chunkIndex - extraElements) * baseChunkLen

            let chunkLen = chunkIndex < extraElements ? maxChunkLen : baseChunkLen

            return Array(self[offset ..< (offset + chunkLen)])
        }
    }
}
