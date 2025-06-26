import Foundation
import CoreImage

extension Data {
    func extractActualDataFromErrorCorrectedPayload() -> Data? {
        let bytes = [UInt8](self)
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

    /// Extract the raw payload from a Byte-mode segment.
    /// - Parameters:
    ///   - codewords: Data region of the QR symbol (error-correction bytes *not* included).
    ///   - version:   Symbol version (1‒40).  Versions 1‒9 use an 8-bit length
    ///                field; versions 10‒40 use a 16-bit length field.
    /// - Returns:     A `Data` object containing exactly the bytes encoded in the QR symbol.
    /// - Throws:      `FormatError` if the stream is malformed (wrong mode, truncated, etc.).
    func extractBytePayload(for version: Int) throws -> Data {
        struct FormatError: Error {}
        precondition((1 ... 40).contains(version), "Version must be 1‒40")

        // ---- Bit reader ----------------------------------------------------
        let bytes = [UInt8](self) // local copy for fast random access
        var bitIndex = 0 // position in bits

        @inline(__always)
        func take(_ num: Int) throws -> Int {
            var value = 0
            for _ in 0 ..< num {
                let bytePos = bitIndex >> 3
                guard bytePos < bytes.count else { throw FormatError() }
                let bit = (bytes[bytePos] >> (7 - (bitIndex & 7))) & 1
                value = (value << 1) | Int(bit)
                bitIndex += 1
            }
            return value
        }

        // 1. Mode indicator must be 0b0100 (Byte mode) -----------------------
        guard try take(4) == 0b0100 else { throw FormatError() }

        // 2. Character-count indicator (8 or 16 bits) ------------------------
        let lengthBits = version <= 9 ? 8 : 16
        let length = try take(lengthBits)
        guard length >= 0 else { throw FormatError() }

        // 3. Payload bytes ----------------------------------------------------
        var payload = [UInt8]()
        payload.reserveCapacity(length)

        for _ in 0 ..< length {
            payload.append(UInt8(try take(8)))
        }

        return Data(payload)
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
