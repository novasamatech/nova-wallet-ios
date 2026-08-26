import BigInt
import Foundation

/// Root-lane APY engine (spec §6.2), integer arithmetic only.
///
/// Per block and per subnet the runtime mints `alpha_out_emission`, removes the owner cut when
/// `OwnerCutEnabled[netuid]` is set, splits the remainder evenly between miners and validators and
/// routes `root_proportion(netuid)` of the validator half to root stakers
/// (subtensor: `pallets/subtensor/src/coinbase/run_coinbase.rs:290-333`). The even miner/validator
/// split is a source literal there, not a chain constant, so metadata cannot detect a change to it.
///
/// `root_proportion` mirrors `coinbase/block_step.rs:74-84`:
/// `tao * weight / (tao * weight + alpha_issuance)`, with `weight = TaoWeight / u64::MAX`
/// (`staking/stake_utils.rs:162-172`) and `alpha_issuance = SubnetAlphaIn + SubnetAlphaOut`
/// (`stake_utils.rs:20-24`; the third term, the swap pallet's alpha reservoir, is a transient
/// settlement buffer that reads empty on finney and is omitted).
///
/// The order of the integer divisions below is part of the contract — the golden vectors in
/// `SubtensorRootAprCalculatorTests` are hand-derived against exactly this sequence.
enum SubtensorRootAprCalculator {
    /// `alpha_out_emission` is written once per block (`run_coinbase.rs:297`) and blocks are 12 s
    /// (subtensor: `common/src/lib.rs:183`), matching `SubtensorAlphaAprCalculator`
    static let blocksPerYear = BigUInt(2_628_000)

    static let ppmScale = BigUInt(1_000_000)

    /// internal fixed point for `root_proportion`
    static let proportionScale = BigUInt(1_000_000_000_000_000_000)

    /// `TaoWeight` normalises by `u64::MAX`, not by 2^64 (subtensor: `stake_utils.rs:170`)
    static let taoWeightScale = BigUInt(UInt64.max)

    /// half the post-owner-cut emission goes to miners (subtensor: `run_coinbase.rs:319-329`)
    static let validatorShareDivisor = BigUInt(2)

    /// root dividends are recycled instead of accrued while the summed EMA price of the emitting
    /// subnets does not exceed 1 TAO (subtensor: `run_coinbase.rs:343-351, 497-506`)
    static let rootSellPriceThresholdBits = BigUInt(1) << SubtensorStakingPallet.fixedPointFractionalBits

    struct Subnet: Equatable {
        let netuid: UInt16
        let alphaOutEmission: Balance
        let alphaIssuance: Balance
        let price: Balance
        let movingPriceBits: Balance
        let ownerCutEnabled: Bool
    }

    struct Params: Equatable {
        /// raw `SubtensorModule.TaoWeight` storage value, never a hardcoded fraction
        let taoWeight: BigUInt
        /// `SubnetTAO[0]`, delivered as `DynamicInfo[0].taoIn`
        let rootTao: Balance
        /// `SubnetAlphaOut[0]`, delivered as `DynamicInfo[0].alphaOut` — the root stake outstanding
        let rootStake: Balance
        let ownerCut: UInt16
        let subnets: [Subnet]
    }
}

extension SubtensorRootAprCalculator {
    static func rootProportion(
        taoWeight: BigUInt,
        rootTao: Balance,
        alphaIssuance: Balance
    ) -> BigUInt {
        let weighted = rootTao * taoWeight
        let denominator = weighted + alphaIssuance * taoWeightScale

        guard denominator > 0 else {
            return 0
        }

        return weighted * proportionScale / denominator
    }

    /// summed per-block rao of TAO flowing to root stakers, scaled by ``proportionScale``
    static func perBlockRootRaoScaled(for params: Params) -> BigUInt {
        let perU16 = BigUInt(SubtensorStakingPallet.perU16Denominator)
        let ownerRetained = perU16 - BigUInt(min(params.ownerCut, SubtensorStakingPallet.perU16Denominator))

        return params.subnets.reduce(BigUInt.zero) { accum, subnet in
            guard subnet.alphaOutEmission > 0, subnet.netuid != SubtensorStakingPallet.rootNetuid else {
                return accum
            }

            let proportion = rootProportion(
                taoWeight: params.taoWeight,
                rootTao: params.rootTao,
                alphaIssuance: subnet.alphaIssuance
            )

            let retained = subnet.ownerCutEnabled ? ownerRetained : perU16

            let numerator = subnet.alphaOutEmission * subnet.price * retained * proportion
            let denominator = SubtensorStakingPallet.alphaPriceScale * validatorShareDivisor * perU16

            return accum + numerator / denominator
        }
    }

    /// gross annual root return in parts per million, before the picked delegate's take
    static func aprPpm(for params: Params) -> BigUInt? {
        aprPpm(for: params, take: 0)
    }

    /// annual root return in parts per million with the delegate take netted once, at the end
    /// (subtensor: `run_coinbase.rs:869-876`)
    static func aprPpm(for params: Params, take: UInt16) -> BigUInt? {
        guard params.rootStake > 0 else {
            return nil
        }

        let perU16 = BigUInt(SubtensorStakingPallet.perU16Denominator)
        let takeRetained = perU16 - BigUInt(min(take, SubtensorStakingPallet.perU16Denominator))

        let scaled = perBlockRootRaoScaled(for: params)

        let numerator = scaled * blocksPerYear * takeRetained * ppmScale
        let denominator = proportionScale * perU16 * params.rootStake

        return numerator / denominator
    }

    /// True while the network recycles root dividends instead of paying them.
    ///
    /// Declared deviation from `get_network_root_sell_flag` (subtensor: `run_coinbase.rs:497-506`):
    /// the runtime sums `get_moving_alpha_price`, which substitutes a hard 1.0 for any subnet whose
    /// `SubnetMechanism` is 0 (`staking/stake_utils.rs:26-37`), while `DynamicInfo` carries only the
    /// stored `SubnetMovingPrice` and no mechanism field. A stable subnet with a low stored price
    /// therefore counts for less here than on chain, so the only possible error is reporting a pause
    /// that is not happening — which hides the rate rather than inflating it.
    static func isRootEmissionPaused(subnets: [Subnet]) -> Bool {
        let summedMovingPrice = subnets.reduce(BigUInt.zero) { accum, subnet in
            guard subnet.alphaOutEmission > 0, subnet.netuid != SubtensorStakingPallet.rootNetuid else {
                return accum
            }

            return accum + subnet.movingPriceBits
        }

        return summedMovingPrice <= rootSellPriceThresholdBits
    }
}
