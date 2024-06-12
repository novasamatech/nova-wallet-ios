import Foundation
import Operation_iOS

protocol MultipartQrOperationFactoryProtocol {
    func createFromPayloadClosure(_ payloadClosure: @escaping () throws -> Data) -> CompoundOperationWrapper<[Data]>
}

/**
 *  Note: Current implementation adapts single frame to multipart format
 */
final class MultipartQrOperationFactory {
    static let multipartPrefix = Data([0])

    let bytesPerCode: Int

    init(bytesPerCode: Int = 512) {
        self.bytesPerCode = bytesPerCode
    }

    private func createFromPayloadClosure(
        for bytesPerCode: Int,
        payloadClosure: @escaping () throws -> Data
    ) -> CompoundOperationWrapper<[Data]> {
        let operation = ClosureOperation<[Data]> {
            let payload = try payloadClosure()

            let chunks = payload.chunked(by: bytesPerCode)

            var frame = UInt16(chunks.count)
            let frameBytes = Data(bytes: &frame, count: MemoryLayout<UInt16>.size).reversed()

            return chunks.enumerated().map { index, chunk in
                var mapedIndex = UInt16(index)
                let indexBytes = Data(bytes: &mapedIndex, count: MemoryLayout<UInt16>.size).reversed()

                return Self.multipartPrefix + frameBytes + indexBytes + chunk
            }
        }

        return CompoundOperationWrapper(targetOperation: operation)
    }
}

extension MultipartQrOperationFactory: MultipartQrOperationFactoryProtocol {
    func createFromPayloadClosure(
        _ payloadClosure: @escaping () throws -> Data
    ) -> CompoundOperationWrapper<[Data]> {
        createFromPayloadClosure(for: bytesPerCode, payloadClosure: payloadClosure)
    }
}
