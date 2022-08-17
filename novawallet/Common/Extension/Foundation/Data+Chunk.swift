import Foundation

extension Data {
    func chunked(by size: Int) -> [Data] {
        var remainedData = self
        var chunks: [Data] = []

        while !remainedData.isEmpty {
            let chunk = remainedData.prefix(size)
            chunks.append(chunk)

            remainedData = remainedData.dropFirst(chunk.count)
        }

        return chunks
    }
}
