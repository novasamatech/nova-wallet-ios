import BigInt
import Foundation

protocol SubtensorRewardCalculatorEngineProtocol: AnyObject {
    /// true while root dividends are recycled by the network instead of paid out (spec §6.2)
    var isRootEmissionPaused: Bool { get }

    /// gross-of-take annual root return as a fraction, nil when no honest number exists
    func rootAnnualReturn() -> Decimal?

    /// annual root return as a fraction with the picked delegate's take netted (spec §6.2)
    func rootAnnualReturn(take: UInt16) -> Decimal?
}

/// Assembled root-lane engine (spec §6.2). Never writes the dashboard — `maxApy` there stays
/// offchain-owned (spec §3.3) — and never produces a number for the subnet lane, which is
/// denominated in a floating token and carries no TAO-denominated headline (spec §6.3).
final class SubtensorRewardCalculatorEngine {
    static let ppmPrecision: UInt16 = 6

    let params: SubtensorRootAprCalculator.Params

    private let pausedFlag: Bool

    init(params: SubtensorRootAprCalculator.Params) {
        self.params = params

        pausedFlag = SubtensorRootAprCalculator.isRootEmissionPaused(subnets: params.subnets)
    }
}

extension SubtensorRewardCalculatorEngine: SubtensorRewardCalculatorEngineProtocol {
    var isRootEmissionPaused: Bool {
        pausedFlag
    }

    func rootAnnualReturn() -> Decimal? {
        rootAnnualReturn(take: 0)
    }

    func rootAnnualReturn(take: UInt16) -> Decimal? {
        guard !pausedFlag else {
            return nil
        }

        guard let ppm = SubtensorRootAprCalculator.aprPpm(for: params, take: take) else {
            return nil
        }

        return ppm.decimal(precision: Self.ppmPrecision)
    }
}
