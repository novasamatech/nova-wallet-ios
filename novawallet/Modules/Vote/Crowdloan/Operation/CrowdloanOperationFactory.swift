import Foundation
import RobinHood
import SubstrateSdk
import IrohaCrypto
import BigInt

protocol CrowdloanOperationFactoryProtocol {
    func fetchCrowdloansOperation(
        connection: JSONRPCEngine,
        runtimeService: RuntimeCodingServiceProtocol
    ) -> CompoundOperationWrapper<[Crowdloan]>

    func fetchContributionOperation(
        connection: JSONRPCEngine,
        runtimeService: RuntimeCodingServiceProtocol,
        accountId: AccountId,
        index: FundIndex
    ) -> CompoundOperationWrapper<CrowdloanContributionResponse>

    func fetchLeaseInfoOperation(
        connection: JSONRPCEngine,
        runtimeService: RuntimeCodingServiceProtocol,
        params: [LeaseParam]
    ) -> CompoundOperationWrapper<[ParachainLeaseInfo]>
}

final class CrowdloanOperationFactory {
    let operationManager: OperationManagerProtocol
    let requestOperationFactory: StorageRequestFactoryProtocol

    init(requestOperationFactory: StorageRequestFactoryProtocol, operationManager: OperationManagerProtocol) {
        self.requestOperationFactory = requestOperationFactory
        self.operationManager = operationManager
    }
}

extension CrowdloanOperationFactory: CrowdloanOperationFactoryProtocol {
    func fetchCrowdloansOperation(
        connection: JSONRPCEngine,
        runtimeService: RuntimeCodingServiceProtocol
    ) -> CompoundOperationWrapper<[Crowdloan]> {
        let coderFactoryOperation = runtimeService.fetchCoderFactoryOperation()

        let codingKeyFactory = StorageKeyFactory()

        let mapper = StorageKeySuffixMapper<StringScaleMapper<UInt32>>(
            type: SubstrateConstants.paraIdType,
            suffixLength: SubstrateConstants.paraIdLength,
            coderFactoryClosure: { try coderFactoryOperation.extractNoCancellableResultData() }
        )

        let paraIdsOperation = StorageKeysQueryService(
            connection: connection,
            operationManager: operationManager,
            prefixKeyClosure: { try codingKeyFactory.key(from: .crowdloanFunds) },
            mapper: AnyMapper(mapper: mapper)
        ).longrunOperation()

        paraIdsOperation.addDependency(coderFactoryOperation)

        let fundsOperation: CompoundOperationWrapper<[StorageResponse<CrowdloanFunds>]> =
            requestOperationFactory.queryItems(
                engine: connection,
                keyParams: {
                    try paraIdsOperation.extractNoCancellableResultData()
                },
                factory: {
                    try coderFactoryOperation.extractNoCancellableResultData()
                }, storagePath: .crowdloanFunds
            )

        fundsOperation.allOperations.forEach { $0.addDependency(paraIdsOperation) }

        let mapOperation = ClosureOperation<[Crowdloan]> {
            try fundsOperation.targetOperation.extractNoCancellableResultData().compactMap { response in
                guard let fundInfo = response.value, let paraId = mapper.map(input: response.key)?.value else {
                    return nil
                }

                return Crowdloan(paraId: paraId, fundInfo: fundInfo)
            }
        }

        mapOperation.addDependency(fundsOperation.targetOperation)

        let dependencies = [coderFactoryOperation, paraIdsOperation] + fundsOperation.allOperations

        return CompoundOperationWrapper(targetOperation: mapOperation, dependencies: dependencies)
    }

    func fetchContributionOperation(
        connection: JSONRPCEngine,
        runtimeService: RuntimeCodingServiceProtocol,
        accountId: AccountId,
        index: FundIndex
    ) -> CompoundOperationWrapper<CrowdloanContributionResponse> {
        let coderFactoryOperation = runtimeService.fetchCoderFactoryOperation()

        let storageKeyParam: () throws -> Data = { accountId }

        let childKeyParam: () throws -> Data = {
            let indexEncoder = ScaleEncoder()
            try index.encode(scaleEncoder: indexEncoder)
            let indexData = indexEncoder.encode()

            guard let childSuffix = try "crowdloan".data(using: .utf8).map({ $0 + indexData })?.blake2b32() else {
                throw NetworkBaseError.badSerialization
            }

            guard let childKey = ":child_storage:default:".data(using: .utf8).map({ $0 + childSuffix }) else {
                throw NetworkBaseError.badSerialization
            }

            return childKey
        }

        let queryWrapper: CompoundOperationWrapper<ChildStorageResponse<CrowdloanContribution>> =
            requestOperationFactory.queryChildItem(
                engine: connection,
                storageKeyParam: storageKeyParam,
                childKeyParam: childKeyParam,
                factory: { try coderFactoryOperation.extractNoCancellableResultData() },
                mapper: CrowdloanContributionMapper()
            )

        queryWrapper.allOperations.forEach { $0.addDependency(coderFactoryOperation) }

        let mappingOperation = ClosureOperation<CrowdloanContributionResponse> {
            let result = try queryWrapper.targetOperation.extractNoCancellableResultData()
            return CrowdloanContributionResponse(
                accountId: accountId,
                index: index,
                contribution: result.value
            )
        }

        mappingOperation.addDependency(queryWrapper.targetOperation)

        return CompoundOperationWrapper(
            targetOperation: mappingOperation,
            dependencies: [coderFactoryOperation] + queryWrapper.allOperations
        )
    }

    func fetchLeaseInfoOperation(
        connection: JSONRPCEngine,
        runtimeService: RuntimeCodingServiceProtocol,
        params: [LeaseParam]
    ) -> CompoundOperationWrapper<[ParachainLeaseInfo]> {
        let coderFactoryOperation = runtimeService.fetchCoderFactoryOperation()

        let keyParams: () throws -> [StringScaleMapper<ParaId>] = {
            params.map { StringScaleMapper(value: $0.paraId) }
        }

        let queryWrapper: CompoundOperationWrapper<[StorageResponse<[ParachainSlotLease?]>]> =
            requestOperationFactory.queryItems(
                engine: connection,
                keyParams: keyParams,
                factory: { try coderFactoryOperation.extractNoCancellableResultData() },
                storagePath: .parachainSlotLeases
            )

        queryWrapper.allOperations.forEach { $0.addDependency(coderFactoryOperation) }

        let mapOperation: BaseOperation<[ParachainLeaseInfo]> = ClosureOperation {
            let queryResult = try queryWrapper.targetOperation.extractNoCancellableResultData()

            return try queryResult.enumerated().map { index, slotLeaseResponse in
                let leaseParam = params[index]

                let bidderAccountId = try leaseParam.bidderKey.fundAccountId()

                guard let leasedAmountList = slotLeaseResponse.value else {
                    return ParachainLeaseInfo(
                        param: leaseParam,
                        fundAccountId: bidderAccountId,
                        leasedAmount: nil
                    )
                }

                let paraAccountId = try leaseParam.paraId.fundAccountId()

                let leaseInfo = leasedAmountList
                    .compactMap { $0 }
                    .filter { $0.accountId == bidderAccountId || $0.accountId == paraAccountId }
                    .max { $0.amount > $1.amount }

                return ParachainLeaseInfo(
                    param: leaseParam,
                    fundAccountId: leaseInfo?.accountId ?? bidderAccountId,
                    leasedAmount: leaseInfo?.amount
                )
            }
        }

        mapOperation.addDependency(queryWrapper.targetOperation)

        return CompoundOperationWrapper(
            targetOperation: mapOperation,
            dependencies: [coderFactoryOperation] + queryWrapper.allOperations
        )
    }
}
