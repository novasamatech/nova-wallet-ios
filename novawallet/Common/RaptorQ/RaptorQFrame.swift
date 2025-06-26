import Foundation

struct RaptorQFrame {
    let totalLength: UInt32
    let packet: Data

    init?(payload: Data) {
        // Need at least 4-byte prefix + 4-byte TAG
        guard payload.count >= 4 else { return nil }

        let prefix = UInt32(bigEndianData: payload.prefix(4))

        // Marker bit (= MSB) must be 1
        guard (prefix & 0x8000_0000) != 0 else { return nil }

        totalLength = prefix & 0x7FFF_FFFF
        packet = payload.subdata(in: 4 ..< payload.count)
    }
}
