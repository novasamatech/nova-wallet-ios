import Foundation
import BigInt

protocol RewardCalculatorEngineFactoryProtocol {
    func createRewardCalculator(
        for totalIssuance: BigUInt,
        validators: [EraValidatorInfo],
        eraDurationInSeconds: TimeInterval
    ) -> RewardCalculatorEngineProtocol
}

final class RewardCalculatorEngineFactory: RewardCalculatorEngineFactoryProtocol {
    let chainId: ChainModel.Id
    let stakingType: StakingType
    let assetPrecision: Int16

    init(chainId: ChainModel.Id, stakingType: StakingType, assetPrecision: Int16) {
        self.chainId = chainId
        self.stakingType = stakingType
        self.assetPrecision = assetPrecision
    }

    func createRewardCalculator(
        for totalIssuance: BigUInt,
        validators: [EraValidatorInfo],
        eraDurationInSeconds: TimeInterval
    ) -> RewardCalculatorEngineProtocol {
        switch stakingType {
        case .azero:
            // https://github.com/Cardinal-Cryptography/aleph-node/blob/r-5.2/primitives/src/lib.rs#L72
            let issuancePerYear: Decimal = 30_000_000
            let treasuryPercentage: Decimal = 0.1

            return UniformCurveRewardEngine(
                chainId: chainId,
                assetPrecision: assetPrecision,
                totalIssuance: totalIssuance,
                validators: validators,
                eraDurationInSeconds: eraDurationInSeconds,
                issuancePerYear: issuancePerYear,
                treasuryPercentage: treasuryPercentage
            )
        default:
            return InflationCurveRewardEngine(
                chainId: chainId,
                assetPrecision: assetPrecision,
                totalIssuance: totalIssuance,
                validators: validators,
                eraDurationInSeconds: eraDurationInSeconds
            )
        }
    }
}
