import Foundation
import Operation_iOS
import BigInt

protocol NetworkStakingInfoOperationFactoryProtocol {
    func networkStakingOperation(
        for eraValidatorService: EraValidatorServiceProtocol,
        runtimeService: RuntimeCodingServiceProtocol
    ) -> CompoundOperationWrapper<NetworkStakingInfo>
}

final class NetworkStakingInfoOperationFactory {
    // MARK: - Private functions

    let durationOperationFactory: StakingDurationOperationFactoryProtocol
    let votersOperationFactory: VotersInfoOperationFactoryProtocol

    init(
        durationFactory: StakingDurationOperationFactoryProtocol,
        votersOperationFactory: VotersInfoOperationFactoryProtocol
    ) {
        durationOperationFactory = durationFactory
        self.votersOperationFactory = votersOperationFactory
    }

    private func createConstOperation<T>(
        dependingOn runtime: BaseOperation<RuntimeCoderFactoryProtocol>,
        path: ConstantCodingPath,
        fallbackValue: T? = nil
    ) -> PrimitiveConstantOperation<T> where T: LosslessStringConvertible {
        let operation = PrimitiveConstantOperation<T>(path: path, fallbackValue: fallbackValue)

        operation.configurationBlock = {
            do {
                operation.codingFactory = try runtime.extractNoCancellableResultData()
            } catch {
                operation.result = .failure(error)
            }
        }

        return operation
    }

    private func deriveTotalStake(from eraStakersInfo: EraStakersInfo) -> BigUInt {
        eraStakersInfo.validators
            .map(\.exposure.total)
            .reduce(0, +)
    }

    private func extractActiveNominators(
        from eraStakersInfo: EraStakersInfo,
        limitedBy maxNominators: UInt32?
    ) -> Set<AccountId> {
        eraStakersInfo.validators.map(\.exposure.others)
            .flatMap { nominators in
                maxNominators.map { Array(nominators.prefix(Int($0))) } ?? nominators
            }
            .reduce(into: Set<Data>()) { $0.insert($1.who) }
    }

    private func deriveMinimalStake(
        from eraStakersInfo: EraStakersInfo,
        limitedBy maxNominators: UInt32?
    ) -> BigUInt {
        let stakeDistribution = eraStakersInfo.validators
            .flatMap(\.exposure.others)
            .reduce(into: [Data: BigUInt]()) { result, item in
                if let stake = result[item.who] {
                    result[item.who] = stake + item.value
                } else {
                    result[item.who] = item.value
                }
            }

        let activeNominators = extractActiveNominators(
            from: eraStakersInfo,
            limitedBy: maxNominators
        )

        return stakeDistribution
            .filter { activeNominators.contains($0.key) }
            .map(\.value)
            .min() ?? BigUInt.zero
    }

    private func deriveActiveNominatorsCount(
        from eraStakersInfo: EraStakersInfo,
        limitedBy maxNominators: UInt32?
    ) -> Int {
        extractActiveNominators(from: eraStakersInfo, limitedBy: maxNominators).count
    }

    // swiftlint:disable:next function_parameter_count
    private func createMapOperation(
        dependingOn eraValidatorsOperation: BaseOperation<EraStakersInfo>,
        maxNominatorsOperation: BaseOperation<UInt32?>,
        lockUpPeriodOperation: BaseOperation<UInt32>,
        minBalanceOperation: BaseOperation<BigUInt>,
        durationOperation: BaseOperation<StakingDuration>,
        votersOperation: BaseOperation<VotersStakingInfo?>
    ) -> BaseOperation<NetworkStakingInfo> {
        ClosureOperation<NetworkStakingInfo> {
            let eraStakersInfo = try eraValidatorsOperation.extractNoCancellableResultData()
            let maxNominators = try maxNominatorsOperation.extractNoCancellableResultData()
            let lockUpPeriod = try lockUpPeriodOperation.extractNoCancellableResultData()
            let minBalance = try minBalanceOperation.extractNoCancellableResultData()

            let totalStake = self.deriveTotalStake(from: eraStakersInfo)

            let minimalStake = self.deriveMinimalStake(
                from: eraStakersInfo,
                limitedBy: maxNominators
            )

            let activeNominatorsCount = self.deriveActiveNominatorsCount(
                from: eraStakersInfo,
                limitedBy: maxNominators
            )

            let stakingDuration = try durationOperation.extractNoCancellableResultData()

            let votersInfo = try votersOperation.extractNoCancellableResultData()

            return NetworkStakingInfo(
                totalStake: totalStake,
                minStakeAmongActiveNominators: minimalStake,
                minimalBalance: minBalance,
                activeNominatorsCount: activeNominatorsCount,
                lockUpPeriod: lockUpPeriod,
                stakingDuration: stakingDuration,
                votersInfo: votersInfo
            )
        }
    }
}

// MARK: - NetworkStakingInfoOperationFactoryProtocol

extension NetworkStakingInfoOperationFactory: NetworkStakingInfoOperationFactoryProtocol {
    func networkStakingOperation(
        for eraValidatorService: EraValidatorServiceProtocol,
        runtimeService: RuntimeCodingServiceProtocol
    ) -> CompoundOperationWrapper<NetworkStakingInfo> {
        let runtimeOperation = runtimeService.fetchCoderFactoryOperation()

        let maxNominatorsWrapper: CompoundOperationWrapper<UInt32?> = PrimitiveConstantOperation.wrapperNilIfMissing(
            for: Staking.maxNominatorRewardedPerValidatorPath,
            runtimeService: runtimeService
        )

        let lockUpPeriodOperation: BaseOperation<UInt32> =
            createConstOperation(
                dependingOn: runtimeOperation,
                path: Staking.lockUpPeriodPath
            )

        let existentialDepositOperation: BaseOperation<BigUInt> = createConstOperation(
            dependingOn: runtimeOperation,
            path: .existentialDeposit
        )

        lockUpPeriodOperation.addDependency(runtimeOperation)
        existentialDepositOperation.addDependency(runtimeOperation)

        let eraValidatorsOperation = eraValidatorService.fetchInfoOperation()

        let stakingDurationWrapper = durationOperationFactory.createDurationOperation(from: runtimeService)

        let votersWrapper = votersOperationFactory.createVotersInfoWrapper(for: runtimeService)

        let mapOperation = createMapOperation(
            dependingOn: eraValidatorsOperation,
            maxNominatorsOperation: maxNominatorsWrapper.targetOperation,
            lockUpPeriodOperation: lockUpPeriodOperation,
            minBalanceOperation: existentialDepositOperation,
            durationOperation: stakingDurationWrapper.targetOperation,
            votersOperation: votersWrapper.targetOperation
        )

        mapOperation.addDependency(eraValidatorsOperation)
        mapOperation.addDependency(maxNominatorsWrapper.targetOperation)
        mapOperation.addDependency(lockUpPeriodOperation)
        mapOperation.addDependency(existentialDepositOperation)
        mapOperation.addDependency(stakingDurationWrapper.targetOperation)
        mapOperation.addDependency(votersWrapper.targetOperation)

        let dependencies = [
            runtimeOperation,
            eraValidatorsOperation,
            lockUpPeriodOperation,
            existentialDepositOperation
        ] + maxNominatorsWrapper.allOperations + stakingDurationWrapper.allOperations + votersWrapper.allOperations

        return CompoundOperationWrapper(targetOperation: mapOperation, dependencies: dependencies)
    }
}
