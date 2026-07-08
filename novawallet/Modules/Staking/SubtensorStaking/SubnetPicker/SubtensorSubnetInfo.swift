import Foundation

/// Lightweight model for a Bittensor subnet, used by the subnet picker.
struct SubtensorSubnetInfo {
    let netuid: UInt16
    let name: String?
    let taoReserve: UInt64
    let alphaInReserve: UInt64

    /// Spot price in TAO per alpha: taoReserve / alphaInReserve.
    var spotPrice: Double {
        guard alphaInReserve > 0 else { return 0 }
        return Double(taoReserve) / Double(alphaInReserve)
    }
}
