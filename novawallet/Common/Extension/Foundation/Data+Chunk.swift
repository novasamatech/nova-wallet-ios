import Foundation

extension Data {
    func chunked(by size: Int) -> [Data] {
        var offset: Int = 0
        let totalSize = count
        var chunks: [Data] = []

        while offset < totalSize {
            let chunkSize = Swift.min(size, totalSize - offset)
            let chunk = subdata(in: offset..<(offset + chunkSize))
            chunks.append(chunk)

            offset += chunkSize
        }

        return chunks
    }
}
