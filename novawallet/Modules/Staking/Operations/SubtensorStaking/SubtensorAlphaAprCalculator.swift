import BigInt
import Foundation

enum SubtensorAlphaAprCalculator {
    // alpha_out_emission in DynamicInfo is a per-block mint rate, so the annualizer is
    // blocks per year at 12 s blocks; the spec's (1 − root_proportion) carve-out is
    // deliberately approximated away per §6.3
    static let blocksPerYear = BigUInt(2_628_000)

    static let ppmScale = BigUInt(1_000_000)

    static func aprPpm(
        alphaOutEmission: Balance,
        alphaOut: Balance,
        ownerCut: UInt16,
        take: UInt16
    ) -> BigUInt? {
        guard alphaOut > 0 else {
            return nil
        }

        let perU16 = BigUInt(SubtensorStakingPallet.perU16Denominator)
        let ownerRetained = BigUInt(SubtensorStakingPallet.perU16Denominator - ownerCut)
        let takeRetained = BigUInt(SubtensorStakingPallet.perU16Denominator - take)

        let numerator = alphaOutEmission * blocksPerYear * ownerRetained * takeRetained * ppmScale
        let denominator = alphaOut * 2 * perU16 * perU16

        return numerator / denominator
    }

    static func aprPpm(
        for dynamicInfo: SubtensorStakingPallet.DynamicInfo,
        ownerCut: UInt16,
        take: UInt16
    ) -> BigUInt? {
        aprPpm(
            alphaOutEmission: dynamicInfo.alphaOutEmission,
            alphaOut: dynamicInfo.alphaOut,
            ownerCut: ownerCut,
            take: take
        )
    }
}
