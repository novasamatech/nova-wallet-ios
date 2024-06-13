import Foundation
import Operation_iOS
import SubstrateSdk

final class StakingEraStakersExposureFactory {
    let requestFactory: StorageRequestFactoryProtocol

    init(requestFactory: StorageRequestFactoryProtocol) {
        self.requestFactory = requestFactory
    }
}

extension StakingEraStakersExposureFactory: StakingValidatorExposureFactoryProtocol {
    func createWrapper(
        dependingOn validatorsClosure: @escaping () throws -> [ResolvedValidatorEra],
        codingFactoryClosure: @escaping () throws -> RuntimeCoderFactoryProtocol,
        connection: JSONRPCEngine
    ) -> CompoundOperationWrapper<[StakingValidatorExposure]> {
        let fetchWrapper: CompoundOperationWrapper<[StorageResponse<Staking.ValidatorExposure>]>
        fetchWrapper = requestFactory.queryItems(
            engine: connection,
            keyParams1: { try validatorsClosure().map { StringScaleMapper(value: $0.era) } },
            keyParams2: { try validatorsClosure().map { BytesCodable(wrappedValue: $0.validator) } },
            factory: codingFactoryClosure,
            storagePath: Staking.erasStakers
        )

        let mappingOperation = ClosureOperation<[StakingValidatorExposure]> {
            let remoteResponses = try fetchWrapper.targetOperation.extractNoCancellableResultData()
            let validators = try validatorsClosure()

            return zip(validators, remoteResponses).compactMap { pair in
                let validatorEra = pair.0
                let remoteResponse = pair.1

                guard let exposure = remoteResponse.value else {
                    return nil
                }

                return StakingValidatorExposure(
                    accountId: validatorEra.validator,
                    era: validatorEra.era,
                    totalStake: exposure.total,
                    ownStake: exposure.own,
                    pages: [exposure.others]
                )
            }
        }

        mappingOperation.addDependency(fetchWrapper.targetOperation)

        return CompoundOperationWrapper(targetOperation: mappingOperation, dependencies: fetchWrapper.allOperations)
    }
}
