import Foundation

extension UInt16 {
    var bigEndianBytes: [UInt8] {
        var value = bigEndian

        return withUnsafeBytes(of: &value, Array.init)
    }

    var littleEndianBytes: [UInt8] {
        var value = littleEndian

        return withUnsafeBytes(of: &value, Array.init)
    }

    init(bigEndianData: Data) {
        let bytes = [UInt8](bigEndianData)

        self = (UInt16(bytes[0]) << 8) | UInt16(bytes[1])
    }
}

extension UInt32 {
    var bigEndianBytes: [UInt8] {
        var value = bigEndian

        return withUnsafeBytes(of: &value, Array.init)
    }

    var littleEndianBytes: [UInt8] {
        var value = littleEndian

        return withUnsafeBytes(of: &value, Array.init)
    }

    init(bigEndianData: Data) {
        let bytes = [UInt8](bigEndianData)

        self = (UInt32(bytes[0]) << 24) | (UInt32(bytes[1]) << 16) | (UInt32(bytes[2]) << 8) | UInt32(bytes[3])
    }
}
