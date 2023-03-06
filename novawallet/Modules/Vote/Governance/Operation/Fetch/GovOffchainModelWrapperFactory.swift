import Foundation
import SubstrateSdk
import RobinHood

class GovOffchainModelWrapperFactory<P, R: Equatable> {
    struct MetadataParams {
        let operationFactory: GovernanceDelegateMetadataFactoryProtocol
        let closure: (R) throws -> [AccountId]?
    }

    struct IdentityParams {
        let operationFactory: IdentityOperationFactoryProtocol
        let closure: (R) throws -> [AccountId]
    }

    let metadataParams: MetadataParams?
    let identityParams: IdentityParams?

    init(
        identityParams: IdentityParams? = nil,
        metadataParams: MetadataParams? = nil
    ) {
        self.identityParams = identityParams
        self.metadataParams = metadataParams
    }

    private func createIdentityWrapper(
        dependingOn modelOperation: BaseOperation<R>,
        chain: ChainModel,
        connection: JSONRPCEngine,
        runtimeService: RuntimeCodingServiceProtocol
    ) -> CompoundOperationWrapper<[AccountId: AccountIdentity]> {
        if let identityParams = identityParams {
            return identityParams.operationFactory.createIdentityWrapperByAccountId(
                for: {
                    let model = try modelOperation.extractNoCancellableResultData()
                    return try identityParams.closure(model)
                },
                engine: connection,
                runtimeService: runtimeService,
                chainFormat: chain.chainFormat
            )
        } else {
            return CompoundOperationWrapper.createWithResult([:])
        }
    }

    private func createMetadataWrapper(
        dependingOn modelOperation: BaseOperation<R>,
        chain: ChainModel
    ) -> CompoundOperationWrapper<[AccountId: GovernanceDelegateMetadataRemote]> {
        if let metadataParams = metadataParams {
            let metadataOperation = metadataParams.operationFactory.fetchMetadataOperation(
                for: chain
            )

            let filterOperation = ClosureOperation<[AccountId: GovernanceDelegateMetadataRemote]> {
                let metadataList = (try? metadataOperation.extractNoCancellableResultData()) ?? []
                let model = try modelOperation.extractNoCancellableResultData()
                let accountIdList = try metadataParams.closure(model)
                let accountIdSet = Set(accountIdList ?? [])

                return metadataList.reduce(
                    into: [AccountId: GovernanceDelegateMetadataRemote]()
                ) { accum, item in
                    guard let accountId = try? item.address.toAccountId() else {
                        return
                    }

                    if accountIdList == nil || accountIdSet.contains(accountId) {
                        accum[accountId] = item
                    }
                }
            }

            filterOperation.addDependency(metadataOperation)

            return CompoundOperationWrapper(
                targetOperation: filterOperation,
                dependencies: [metadataOperation]
            )
        } else {
            return CompoundOperationWrapper.createWithResult([:])
        }
    }

    private func createMergeOperation(
        dependingOn modelOperation: BaseOperation<R>,
        metadataOperation: BaseOperation<[AccountId: GovernanceDelegateMetadataRemote]>,
        identitiesOperation: BaseOperation<[AccountId: AccountIdentity]>
    ) -> BaseOperation<GovernanceDelegationAdditions<R>> {
        ClosureOperation<GovernanceDelegationAdditions<R>> {
            let model = try modelOperation.extractNoCancellableResultData()
            let metadataDict = try metadataOperation.extractNoCancellableResultData()
            let identities = try identitiesOperation.extractNoCancellableResultData()

            return .init(model: model, identities: identities, metadata: metadataDict)
        }
    }

    func createModelWrapper(for _: P, chain _: ChainModel) -> CompoundOperationWrapper<R> {
        fatalError("Child factory must override this method")
    }

    func createWrapper(
        for params: P,
        chain: ChainModel,
        connection: JSONRPCEngine,
        runtimeService: RuntimeCodingServiceProtocol
    ) -> CompoundOperationWrapper<GovernanceDelegationAdditions<R>> {
        let modelWrapper = createModelWrapper(for: params, chain: chain)

        let identityWrapper = createIdentityWrapper(
            dependingOn: modelWrapper.targetOperation,
            chain: chain,
            connection: connection,
            runtimeService: runtimeService
        )

        identityWrapper.addDependency(wrapper: modelWrapper)

        let metadataWrapper = createMetadataWrapper(
            dependingOn: modelWrapper.targetOperation,
            chain: chain
        )

        metadataWrapper.addDependency(wrapper: modelWrapper)

        let mergeOperation = createMergeOperation(
            dependingOn: modelWrapper.targetOperation,
            metadataOperation: metadataWrapper.targetOperation,
            identitiesOperation: identityWrapper.targetOperation
        )

        let dependencies = modelWrapper.allOperations + identityWrapper.allOperations +
            metadataWrapper.allOperations

        dependencies.forEach { mergeOperation.addDependency($0) }

        return CompoundOperationWrapper(
            targetOperation: mergeOperation,
            dependencies: dependencies
        )
    }
}
