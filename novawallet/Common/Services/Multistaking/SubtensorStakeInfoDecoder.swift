import Foundation
import BigInt

/// SCALE decoder for the `Vec<StakeInfo>` payload returned by Bittensor's
/// `state_call("StakeInfoRuntimeApi_get_stake_info_for_coldkey", coldkey)`.
///
/// Field order matches `pallets/subtensor/src/rpc_info/stake_info.rs`. If
/// upstream adds a field before `isRegistered`, update the skip count in
/// `decodeEntry` — the `SubtensorPositionFetcher` and `SubtensorPositionCache`
/// both come through here, so a single update fixes both call sites.
enum SubtensorStakeInfoDecoder {
    struct Entry {
        /// Validator hotkey.
        let hotkey: AccountId
        let coldkey: AccountId
        /// 0 = root, >0 = subnet id.
        let netuid: UInt16
        /// Resolved stake amount in the subnet's smallest unit
        /// (RAO for root, alpha-units for subnets).
        let stake: BigUInt
    }

    static func decode(hex: String) -> [Entry] {
        let bytes = hexToBytes(hex)
        guard !bytes.isEmpty,
              let (count, posAfterCount) = scaleCompact(bytes: bytes, offset: 0)
        else { return [] }

        var result: [Entry] = []
        var pos = posAfterCount
        for _ in 0 ..< Int(count) {
            guard let (entry, nextPos) = decodeEntry(bytes: bytes, offset: pos) else {
                // Stop on malformed entry; return what we successfully decoded.
                return result
            }
            result.append(entry)
            pos = nextPos
        }
        return result
    }

    private static func decodeEntry(bytes: [UInt8], offset: Int) -> (Entry, Int)? {
        var pos = offset

        // hotkey: AccountId32 (32 raw bytes)
        guard pos + 32 <= bytes.count else { return nil }
        let hotkey = Data(bytes[pos ..< pos + 32])
        pos += 32

        // coldkey: AccountId32 (32 raw bytes)
        guard pos + 32 <= bytes.count else { return nil }
        let coldkey = Data(bytes[pos ..< pos + 32])
        pos += 32

        // netuid: Compact<u16>
        guard let (netuidBig, posAfterNetuid) = scaleCompact(bytes: bytes, offset: pos) else { return nil }
        pos = posAfterNetuid

        // stake: Compact<U128>
        guard let (stake, posAfterStake) = scaleCompact(bytes: bytes, offset: pos) else { return nil }
        pos = posAfterStake

        // locked, emission, taoEmission, drain — four Compact<U128> we don't use.
        for _ in 0 ..< 4 {
            guard let (_, next) = scaleCompact(bytes: bytes, offset: pos) else { return nil }
            pos = next
        }

        // isRegistered: bool (1 byte)
        guard pos + 1 <= bytes.count else { return nil }
        pos += 1

        return (Entry(
            hotkey: hotkey,
            coldkey: coldkey,
            netuid: UInt16(truncatingIfNeeded: netuidBig),
            stake: stake
        ), pos)
    }

    /// SCALE compact decoder supporting all four modes (1/2/4-byte and
    /// big-integer). Returns `(value, nextOffset)` or `nil` on truncation.
    static func scaleCompact(bytes: [UInt8], offset: Int) -> (BigUInt, Int)? {
        guard offset < bytes.count else { return nil }
        let mode = bytes[offset] & 0x03
        switch mode {
        case 0x00:
            return (BigUInt(bytes[offset] >> 2), offset + 1)
        case 0x01:
            guard offset + 2 <= bytes.count else { return nil }
            let val = (UInt16(bytes[offset]) | (UInt16(bytes[offset + 1]) << 8)) >> 2
            return (BigUInt(val), offset + 2)
        case 0x02:
            guard offset + 4 <= bytes.count else { return nil }
            let raw = UInt32(bytes[offset]) |
                (UInt32(bytes[offset + 1]) << 8) |
                (UInt32(bytes[offset + 2]) << 16) |
                (UInt32(bytes[offset + 3]) << 24)
            return (BigUInt(raw >> 2), offset + 4)
        case 0x03:
            // Big-integer mode: byte0 = (N << 2) | 3, then (N+4) LE bytes.
            let extraBytes = Int(bytes[offset] >> 2)
            let len = extraBytes + 4
            guard offset + 1 + len <= bytes.count else { return nil }
            let leBytes = Array(bytes[(offset + 1) ..< (offset + 1 + len)])
            return (BigUInt(Data(leBytes.reversed())), offset + 1 + len)
        default:
            return nil
        }
    }

    private static func hexToBytes(_ hex: String) -> [UInt8] {
        let clean = hex.hasPrefix("0x") ? String(hex.dropFirst(2)) : hex
        var bytes: [UInt8] = []
        var idx = clean.startIndex
        while let end = clean.index(idx, offsetBy: 2, limitedBy: clean.endIndex),
              end != idx {
            bytes.append(UInt8(clean[idx ..< end], radix: 16) ?? 0)
            idx = end
        }
        return bytes
    }
}
