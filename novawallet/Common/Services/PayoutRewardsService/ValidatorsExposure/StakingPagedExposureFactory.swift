import Foundation
import Operation_iOS
import SubstrateSdk

final class StakingPagedExposureFactory {
    struct EraValidatorPage: Equatable, Hashable, NMapKeyStorageKeyProtocol {
        let accountId: AccountId
        let era: Staking.EraIndex
        let page: Staking.ValidatorPage

        func appendSubkey(to encoder: DynamicScaleEncoding, type: String, index: Int) throws {
            switch index {
            case 0:
                try encoder.append(StringScaleMapper(value: era), ofType: type)
            case 1:
                try encoder.append(BytesCodable(wrappedValue: accountId), ofType: type)
            case 2:
                try encoder.append(StringScaleMapper(value: page), ofType: type)
            default:
                throw CommonError.dataCorruption
            }
        }
    }

    let requestFactory: StorageRequestFactoryProtocol

    init(requestFactory: StorageRequestFactoryProtocol) {
        self.requestFactory = requestFactory
    }

    private func createOverviewWrapper(
        dependingOn validatorsClosure: @escaping () throws -> [ResolvedValidatorEra],
        codingFactoryClosure: @escaping () throws -> RuntimeCoderFactoryProtocol,
        connection: JSONRPCEngine
    ) -> CompoundOperationWrapper<[ResolvedValidatorEra: Staking.ValidatorOverview]> {
        let overviewWrapper: CompoundOperationWrapper<[StorageResponse<Staking.ValidatorOverview>]>
        overviewWrapper = requestFactory.queryItems(
            engine: connection,
            keyParams1: { try validatorsClosure().map { StringScaleMapper(value: $0.era) } },
            keyParams2: { try validatorsClosure().map { BytesCodable(wrappedValue: $0.validator) } },
            factory: codingFactoryClosure,
            storagePath: Staking.eraStakersOverview
        )

        let mergeOperation = ClosureOperation<[ResolvedValidatorEra: Staking.ValidatorOverview]> {
            let overviewResponses = try overviewWrapper.targetOperation.extractNoCancellableResultData()
            let validators = try validatorsClosure()

            return zip(validators, overviewResponses).reduce(
                into: [ResolvedValidatorEra: Staking.ValidatorOverview]()
            ) { accum, pair in
                accum[pair.0] = pair.1.value
            }
        }

        mergeOperation.addDependency(overviewWrapper.targetOperation)

        return CompoundOperationWrapper(targetOperation: mergeOperation, dependencies: overviewWrapper.allOperations)
    }

    private func createPagesFetchWrapper(
        dependingOn overviewClosure: @escaping () throws -> [ResolvedValidatorEra: Staking.ValidatorOverview],
        codingFactoryClosure: @escaping () throws -> RuntimeCoderFactoryProtocol,
        connection: JSONRPCEngine
    ) -> CompoundOperationWrapper<[EraValidatorPage: Staking.ValidatorExposurePage]> {
        let pagesOperation = ClosureOperation<[EraValidatorPage]> {
            let overview = try overviewClosure()
            return overview.flatMap { keyValue in
                let validatorEra = keyValue.key
                let overview = keyValue.value

                return (0 ..< overview.pageCount).map { page in
                    EraValidatorPage(accountId: validatorEra.validator, era: validatorEra.era, page: page)
                }
            }
        }

        let pagesFetchWrapper: CompoundOperationWrapper<[StorageResponse<Staking.ValidatorExposurePage>]>
        pagesFetchWrapper = requestFactory.queryNMapItems(
            engine: connection,
            nParamKeys: { try pagesOperation.extractNoCancellableResultData() },
            factory: codingFactoryClosure,
            storagePath: Staking.eraStakersPaged
        )

        pagesFetchWrapper.addDependency(operations: [pagesOperation])

        let mergeOperation = ClosureOperation<[EraValidatorPage: Staking.ValidatorExposurePage]> {
            let pages = try pagesOperation.extractNoCancellableResultData()
            let pagesResponses = try pagesFetchWrapper.targetOperation.extractNoCancellableResultData()

            return zip(pages, pagesResponses).reduce(
                into: [EraValidatorPage: Staking.ValidatorExposurePage]()
            ) { accum, pair in
                accum[pair.0] = pair.1.value
            }
        }

        mergeOperation.addDependency(pagesFetchWrapper.targetOperation)

        return CompoundOperationWrapper(
            targetOperation: mergeOperation,
            dependencies: [pagesOperation] + pagesFetchWrapper.allOperations
        )
    }
}

extension StakingPagedExposureFactory: StakingValidatorExposureFactoryProtocol {
    func createWrapper(
        dependingOn validatorsClosure: @escaping () throws -> [ResolvedValidatorEra],
        codingFactoryClosure: @escaping () throws -> RuntimeCoderFactoryProtocol,
        connection: JSONRPCEngine
    ) -> CompoundOperationWrapper<[StakingValidatorExposure]> {
        let overviewWrapper = createOverviewWrapper(
            dependingOn: validatorsClosure,
            codingFactoryClosure: codingFactoryClosure,
            connection: connection
        )

        let pagesWrapper = createPagesFetchWrapper(
            dependingOn: { try overviewWrapper.targetOperation.extractNoCancellableResultData() },
            codingFactoryClosure: codingFactoryClosure,
            connection: connection
        )

        pagesWrapper.addDependency(wrapper: overviewWrapper)

        let mergeOperation = ClosureOperation<[StakingValidatorExposure]> {
            let overviewDict = try overviewWrapper.targetOperation.extractNoCancellableResultData()
            let pagesDict = try pagesWrapper.targetOperation.extractNoCancellableResultData()

            return overviewDict.compactMap { keyValue in
                let validatorEra = keyValue.key
                let overview = keyValue.value

                let otherPages: [[Staking.IndividualExposure]] = (0 ..< overview.pageCount).map { pageIndex in
                    let eraValidatorPage = EraValidatorPage(
                        accountId: validatorEra.validator,
                        era: validatorEra.era,
                        page: Staking.ValidatorPage(pageIndex)
                    )

                    return pagesDict[eraValidatorPage]?.others ?? []
                }

                return StakingValidatorExposure(
                    accountId: validatorEra.validator,
                    era: validatorEra.era,
                    totalStake: overview.total,
                    ownStake: overview.own,
                    pages: otherPages
                )
            }
        }

        mergeOperation.addDependency(pagesWrapper.targetOperation)

        let dependencies = overviewWrapper.allOperations + pagesWrapper.allOperations

        return CompoundOperationWrapper(targetOperation: mergeOperation, dependencies: dependencies)
    }
}
