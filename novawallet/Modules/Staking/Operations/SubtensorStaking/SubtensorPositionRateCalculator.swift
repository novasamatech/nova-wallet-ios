import BigInt
import Foundation

/// Per-position "≈ X α/day" (spec §6.1).
///
/// `StakeInfo.emission` is `AlphaDividendsPerSubnet[netuid, hotkey]`
/// (subtensor: `rpc_info/stake_info.rs:69`), which is
/// - **hotkey-wide**, identical for every coldkey delegating to that hotkey,
/// - **one tempo's worth**: the map is cleared and rewritten each epoch
///   (`coinbase/run_coinbase.rs:808, 831-834`), and
/// - **already net of the validator take**: the take is subtracted before the value is stored
///   (`run_coinbase.rs:809-834`), and is credited back into the same share pool as a separate
///   stake add, so it sits inside `TotalHotkeyAlpha` and must not be deducted a second time.
///
/// The pool grows every holder strictly pro rata
/// (`staking/stake_utils.rs:547-554`), so position alpha over hotkey alpha is the exact splitter.
enum SubtensorPositionRateCalculator {
    /// 12 s blocks (subtensor: `common/src/lib.rs:183`)
    static let blocksPerDay = BigUInt(7200)

    /// rao of alpha this position accrues per day, nil when no honest number exists
    static func alphaPerDayRao(
        hotkeyEmissionPerTempo: Balance,
        positionAlpha: Balance,
        totalHotkeyAlpha: Balance,
        tempo: UInt16
    ) -> Balance? {
        guard totalHotkeyAlpha > 0, tempo > 0 else {
            return nil
        }

        let numerator = hotkeyEmissionPerTempo * positionAlpha * blocksPerDay
        let denominator = totalHotkeyAlpha * BigUInt(tempo)

        return numerator / denominator
    }

    /// `distribute_emission` skips the root subnet entirely (subtensor: `run_coinbase.rs:37-40`), so
    /// `AlphaDividendsPerSubnet[0, ·]` is never written and a root row must show the claimable
    /// basket rather than a fabricated "≈ 0 α/day"
    static func supportsAlphaPerDay(netuid: UInt16) -> Bool {
        netuid != SubtensorStakingPallet.rootNetuid
    }

    static func alphaPerDayRao(
        for position: SubtensorStakingPosition,
        tempo: UInt16?
    ) -> Balance? {
        guard
            supportsAlphaPerDay(netuid: position.netuid),
            let tempo,
            let totalHotkeyAlpha = position.totalHotkeyAlpha else {
            return nil
        }

        return alphaPerDayRao(
            hotkeyEmissionPerTempo: position.hotkeyEmissionPerTempo,
            positionAlpha: position.stakeAlpha,
            totalHotkeyAlpha: totalHotkeyAlpha,
            tempo: tempo
        )
    }
}
