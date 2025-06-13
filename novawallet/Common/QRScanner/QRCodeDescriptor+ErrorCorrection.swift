import Foundation
import CoreImage

extension CIQRCodeDescriptor {
    func extractActualDataFromCorrectedPayload() -> Data? {
        let bytes = [UInt8](errorCorrectedPayload)
        guard !bytes.isEmpty else { return nil }

        // --- 1. Decode header -------------------------------------------------
        // First 4 bits: mode. In Byte mode they are 0b0100 (= 0x4)
        let mode = bytes[0] >> 4
        guard mode == 0b0100 else { return nil }

        // Character-count indicator: 8 bits for version 1-9.
        // They start in the low nibble of byte 0 and finish in the high nibble of byte 1.
        let length = Int(((bytes[0] & 0x0F) << 4) | (bytes[1] >> 4))

        // --- 2. Extract message ----------------------------------------------
        // Message starts at bit offset 12 (4 for mode + 8 for length),
        // i.e. byte offset 1, bit offset 4.
        var result = [UInt8]()
        var bitIndex = 12 // current read position
        for _ in 0 ..< length {
            let nextByte = bytes.readByte(from: bitIndex)
            result.append(nextByte)
            bitIndex += 8
        }
        return Data(result)
    }
}

private extension Array where Element == UInt8 {
    func readBit(at bitIndex: Int) -> UInt8 {
        let byte = self[bitIndex / 8]
        let bit = 7 - (bitIndex % 8)
        return (byte >> bit) & 1
    }

    func readByte(from bitIndex: Int) -> UInt8 {
        (0 ..< 8).reduce(0) { acc, index in (acc << 1) | readBit(at: bitIndex + index) }
    }
}
