import Foundation
import RobinHood

protocol MultipartQrOperationFactoryProtocol {
    func createFromPayloadClosure(_ payloadClosure: () throws -> Data) -> CompoundOperationWrapper<[Data]>
}

/**
 *  Note: Current implementation adapts single frame to multipart format
 */
final class MultipartQrOperationFactory {
    static let multipartPrefix: Data = Data([0])
}

extension MultipartQrOperationFactory: MultipartQrOperationFactoryProtocol {
    func createFromPayloadClosure(_ payloadClosure: () throws -> Data) -> CompoundOperationWrapper<[Data]> {
        let operation = ClosureOperation<[Data]> {
            let payload = try payloadClosure()

            var frame: UInt16 = 1
            var index: UInt16 = 0

            let frameBytes = Data(bytes: &frame, count: MemoryLayout<UInt16>.size)
            let indexBytes = Data(bytes: &index, count: MemoryLayout<UInt16>.size)

            let frameRepresentation = Self.multipartPrefix + frameBytes + indexBytes + payload

            return [frameRepresentation]
        }

        return CompoundOperationWrapper(targetOperation: operation)
    }
}
