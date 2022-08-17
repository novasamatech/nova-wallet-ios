import Foundation

extension UInt16 {
    var bigEndianBytes: [UInt8] {
        var value = bigEndian

        return withUnsafeBytes(of: &value, Array.init)
    }

    static func fromBigEndian(data: Data) -> UInt16 {
        UInt16(bigEndian: data.withUnsafeBytes { $0.load(as: UInt16.self) })
    }
}

extension UInt32 {
    var bigEndianBytes: [UInt8] {
        var value = bigEndian

        return withUnsafeBytes(of: &value, Array.init)
    }

    static func fromBigEndian(data: Data) -> UInt32 {
        UInt32(bigEndian: data.withUnsafeBytes { $0.load(as: UInt32.self) })
    }
}

extension UInt64 {
    var bigEndianBytes: [UInt8] {
        var value = bigEndian

        return withUnsafeBytes(of: &value, Array.init)
    }

    static func fromBigEndian(data: Data) -> UInt64 {
        UInt64(bigEndian: data.withUnsafeBytes { $0.load(as: UInt64.self) })
    }
}
