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

    static func fromBigEndian(data: Data) -> UInt16 {
        let bytes = [UInt8](data)

        return (UInt16(bytes[0]) << 8) | UInt16(bytes[1])
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

    static func fromBigEndian(data: Data) -> UInt32 {
        let bytes = [UInt8](data)

        return (UInt32(bytes[0]) << 24) | (UInt32(bytes[1]) << 16) | (UInt32(bytes[2]) << 8) | UInt32(bytes[3])
    }
}
