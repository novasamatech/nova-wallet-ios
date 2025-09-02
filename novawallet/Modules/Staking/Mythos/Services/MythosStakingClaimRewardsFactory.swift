import Foundation
import Operation_iOS
import SubstrateSdk

protocol MythosStakingClaimRewardsFactoryProtocol {
    func shouldClaimRewardsWrapper(
        for chainId: ChainModel.Id,
        accountId: AccountId,
        at blockHash: Data?
    ) -> CompoundOperationWrapper<Bool>

    func totalRewardsWrapper(
        for chainId: ChainModel.Id,
        accountId: AccountId,
        at blockHash: Data?
    ) -> CompoundOperationWrapper<Balance>
}

enum MythosStakingClaimRewardsFactoryError: Error {
    case noApiMethod(String)
}

final class MythosStakingClaimRewardsFactory {
    let runtimeApiFactory: StateCallRequestFactoryProtocol
    let chainRegistry: ChainRegistryProtocol
    let operationQueue: OperationQueue

    init(
        chainRegistry: ChainRegistryProtocol,
        runtimeApiFactory: StateCallRequestFactoryProtocol = StateCallRequestFactory(),
        operationQueue: OperationQueue
    ) {
        self.chainRegistry = chainRegistry
        self.runtimeApiFactory = runtimeApiFactory
        self.operationQueue = operationQueue
    }

    private func createApiWrapper<T: Decodable>(
        dependingOn codingFactoryOperation: BaseOperation<RuntimeCoderFactoryProtocol>,
        accountId: AccountId,
        methodName: String,
        connection: JSONRPCEngine,
        runtimeApiFactory: StateCallRequestFactoryProtocol,
        at blockHash: Data?
    ) -> CompoundOperationWrapper<T> {
        OperationCombiningService.compoundNonOptionalWrapper(
            operationQueue: operationQueue
        ) {
            let codingFactory = try codingFactoryOperation.extractNoCancellableResultData()

            guard
                let runtimeApi = codingFactory.metadata.getRuntimeApiMethod(
                    for: "CollatorStakingApi",
                    methodName: methodName
                ),
                let paramType = runtimeApi.method.inputs.first else {
                throw MythosStakingClaimRewardsFactoryError.noApiMethod(methodName)
            }

            return runtimeApiFactory.createWrapper(
                for: runtimeApi.callName,
                paramsClosure: { encoder, context in
                    try encoder.append(
                        BytesCodable(wrappedValue: accountId),
                        ofType: String(paramType.paramType),
                        with: context.toRawContext()
                    )
                },
                codingFactoryClosure: {
                    try codingFactoryOperation.extractNoCancellableResultData()
                },
                connection: connection,
                queryType: String(runtimeApi.method.output),
                at: blockHash?.toHexWithPrefix()
            )
        }
    }
}

extension MythosStakingClaimRewardsFactory: MythosStakingClaimRewardsFactoryProtocol {
    func shouldClaimRewardsWrapper(
        for chainId: ChainModel.Id,
        accountId: AccountId,
        at blockHash: Data?
    ) -> CompoundOperationWrapper<Bool> {
        do {
            let connection = try chainRegistry.getConnectionOrError(for: chainId)
            let runtimeProvider = try chainRegistry.getRuntimeProviderOrError(for: chainId)

            let codingFactoryOperation = runtimeProvider.fetchCoderFactoryOperation()

            let requestWrapper: CompoundOperationWrapper<Bool> = createApiWrapper(
                dependingOn: codingFactoryOperation,
                accountId: accountId,
                methodName: "should_claim",
                connection: connection,
                runtimeApiFactory: runtimeApiFactory,
                at: blockHash
            )

            requestWrapper.addDependency(operations: [codingFactoryOperation])

            return requestWrapper.insertingHead(operations: [codingFactoryOperation])
        } catch {
            return .createWithError(error)
        }
    }

    func totalRewardsWrapper(
        for chainId: ChainModel.Id,
        accountId: AccountId,
        at blockHash: Data?
    ) -> CompoundOperationWrapper<Balance> {
        do {
            let connection = try chainRegistry.getConnectionOrError(for: chainId)
            let runtimeProvider = try chainRegistry.getRuntimeProviderOrError(for: chainId)

            let codingFactoryOperation = runtimeProvider.fetchCoderFactoryOperation()

            let requestWrapper: CompoundOperationWrapper<StringScaleMapper<Balance>> = createApiWrapper(
                dependingOn: codingFactoryOperation,
                accountId: accountId,
                methodName: "total_rewards",
                connection: connection,
                runtimeApiFactory: runtimeApiFactory,
                at: blockHash
            )

            let mappingOperation = ClosureOperation<Balance> {
                try requestWrapper.targetOperation.extractNoCancellableResultData().value
            }

            requestWrapper.addDependency(operations: [codingFactoryOperation])

            mappingOperation.addDependency(requestWrapper.targetOperation)

            return requestWrapper
                .insertingHead(operations: [codingFactoryOperation])
                .insertingTail(operation: mappingOperation)
        } catch {
            return .createWithError(error)
        }
    }
}
