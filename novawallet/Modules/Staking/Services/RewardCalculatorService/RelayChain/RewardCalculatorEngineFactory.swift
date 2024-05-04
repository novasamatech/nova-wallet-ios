import Foundation
import BigInt

protocol RewardCalculatorEngineFactoryProtocol {
    func createRewardCalculator(
        for totalIssuance: BigUInt,
        params: RewardCalculatorParams,
        validators: [EraValidatorInfo],
        eraDurationInSeconds: TimeInterval
    ) -> RewardCalculatorEngineProtocol
}

final class RewardCalculatorEngineFactory {
    let chainId: ChainModel.Id
    let stakingType: StakingType
    let assetPrecision: Int16

    init(chainId: ChainModel.Id, stakingType: StakingType, assetPrecision: Int16) {
        self.chainId = chainId
        self.stakingType = stakingType
        self.assetPrecision = assetPrecision
    }

    private func createRelaychainCalculator(
        for totalIssuance: BigUInt,
        params: RewardCalculatorParams,
        validators: [EraValidatorInfo],
        eraDurationInSeconds: TimeInterval
    ) -> RewardCalculatorEngineProtocol {
        switch params {
        case .noParams, .inflation:
            let config = InflationCurveRewardConfig.config(for: chainId)
            return InflationCurveRewardEngine(
                chainId: chainId,
                assetPrecision: assetPrecision,
                totalIssuance: totalIssuance,
                validators: validators,
                eraDurationInSeconds: eraDurationInSeconds,
                config: config,
                parachainsCount: params.parachainsCount ?? 0
            )
        case let .vara(inflation):
            return VaraRewardEngine(
                chainId: chainId,
                assetPrecision: assetPrecision,
                annualInflation: inflation,
                totalIssuance: totalIssuance,
                validators: validators,
                eraDurationInSeconds: eraDurationInSeconds
            )
        }
    }
}

extension RewardCalculatorEngineFactory: RewardCalculatorEngineFactoryProtocol {
    func createRewardCalculator(
        for totalIssuance: BigUInt,
        params: RewardCalculatorParams,
        validators: [EraValidatorInfo],
        eraDurationInSeconds: TimeInterval
    ) -> RewardCalculatorEngineProtocol {
        switch stakingType {
        case .azero:
            // https://github.com/Cardinal-Cryptography/aleph-node/blob/r-5.2/primitives/src/lib.rs#L72
            let issuancePerYear: Decimal = 30_000_000
            let treasuryPercentage: Decimal = 0.1

            return AlephZeroRewardEngine(
                chainId: chainId,
                assetPrecision: assetPrecision,
                totalIssuance: totalIssuance,
                validators: validators,
                eraDurationInSeconds: eraDurationInSeconds,
                issuancePerYear: issuancePerYear,
                treasuryPercentage: treasuryPercentage
            )
        default:
            return createRelaychainCalculator(
                for: totalIssuance,
                params: params,
                validators: validators,
                eraDurationInSeconds: eraDurationInSeconds
            )
        }
    }
}
