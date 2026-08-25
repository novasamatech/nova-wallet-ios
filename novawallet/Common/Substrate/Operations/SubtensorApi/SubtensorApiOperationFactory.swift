import Foundation
import SubstrateSdk
import Operation_iOS

protocol SubtensorApiOperationFactoryProtocol {
    func createBestBlockHashWrapper() -> CompoundOperationWrapper<BlockHash>

    func createStakeInfoWrapper(
        for coldkey: AccountId,
        blockHash: BlockHash?
    ) -> CompoundOperationWrapper<[SubtensorStakingPallet.StakeInfo]>

    func createStakeAvailabilityWrapper(
        for coldkeys: [AccountId],
        netuids: [UInt16]?,
        blockHash: BlockHash?
    ) -> CompoundOperationWrapper<[SubtensorStakingPallet.ColdkeyStakeAvailability]>

    func createAllDynamicInfoWrapper(
        at blockHash: BlockHash?
    ) -> CompoundOperationWrapper<[SubtensorStakingPallet.DynamicInfo?]>

    func createDelegatesWrapper(
        at blockHash: BlockHash?
    ) -> CompoundOperationWrapper<[SubtensorStakingPallet.DelegateInfo]>

    func createAlphaPricesWrapper(
        at blockHash: BlockHash?
    ) -> CompoundOperationWrapper<[SubtensorStakingPallet.SubnetPrice]>

    func createRootBasketOwedWrapper(
        for coldkey: AccountId,
        blockHash: BlockHash?
    ) -> CompoundOperationWrapper<Balance>

    func createRootBasketPositionsWrapper(
        for coldkey: AccountId,
        blockHash: BlockHash?
    ) -> CompoundOperationWrapper<[SubtensorStakingPallet.RootBasketPosition]>
}

extension SubtensorApiOperationFactoryProtocol {
    func createStakeInfoWrapper(
        for coldkey: AccountId
    ) -> CompoundOperationWrapper<[SubtensorStakingPallet.StakeInfo]> {
        createStakeInfoWrapper(for: coldkey, blockHash: nil)
    }

    func createAllDynamicInfoWrapper() -> CompoundOperationWrapper<[SubtensorStakingPallet.DynamicInfo?]> {
        createAllDynamicInfoWrapper(at: nil)
    }

    func createDelegatesWrapper() -> CompoundOperationWrapper<[SubtensorStakingPallet.DelegateInfo]> {
        createDelegatesWrapper(at: nil)
    }

    func createAlphaPricesWrapper() -> CompoundOperationWrapper<[SubtensorStakingPallet.SubnetPrice]> {
        createAlphaPricesWrapper(at: nil)
    }

    func createRootBasketOwedWrapper(
        for coldkey: AccountId
    ) -> CompoundOperationWrapper<Balance> {
        createRootBasketOwedWrapper(for: coldkey, blockHash: nil)
    }

    func createRootBasketPositionsWrapper(
        for coldkey: AccountId
    ) -> CompoundOperationWrapper<[SubtensorStakingPallet.RootBasketPosition]> {
        createRootBasketPositionsWrapper(for: coldkey, blockHash: nil)
    }
}

final class SubtensorApiOperationFactory {
    let runtimeConnectionStore: RuntimeConnectionStoring
    let operationQueue: OperationQueue

    let stateCallFactory: StateCallRequestFactory
    let blockHashOperationFactory = BlockHashOperationFactory()

    init(
        runtimeConnectionStore: RuntimeConnectionStoring,
        operationQueue: OperationQueue,
        rpcTimeout: Int = JSONRPCTimeout.singleNode
    ) {
        self.runtimeConnectionStore = runtimeConnectionStore
        self.operationQueue = operationQueue

        stateCallFactory = StateCallRequestFactory(rpcTimeout: rpcTimeout)
    }

    private func createAccountParamsClosure(for accountId: AccountId) -> StateCallWithApiParamsClosure {
        { runtimeApi, encoder, context in
            let paramsCount = runtimeApi.method.inputs.count
            guard paramsCount == 1 else {
                throw SubstrateRuntimeApiOperationFactoryError.unexpectedParamsCount
            }

            try encoder.append(
                BytesCodable(wrappedValue: accountId),
                ofType: runtimeApi.method.inputs[0].paramType.asTypeId(),
                with: context.toRawContext()
            )
        }
    }

    private func createWrapper<R: Decodable>(
        path: StateCallPath,
        blockHash: BlockHash?,
        paramsClosure: StateCallWithApiParamsClosure?
    ) -> CompoundOperationWrapper<R> {
        do {
            let runtimeProvider = try runtimeConnectionStore.getRuntimeProvider()
            let connection = try runtimeConnectionStore.getConnection()

            return stateCallFactory.createWrapper(
                path: path,
                paramsClosure: paramsClosure,
                runtimeProvider: runtimeProvider,
                connection: connection,
                operationQueue: operationQueue,
                at: blockHash
            )
        } catch {
            return CompoundOperationWrapper.createWithError(error)
        }
    }
}

extension SubtensorApiOperationFactory: SubtensorApiOperationFactoryProtocol {
    func createBestBlockHashWrapper() -> CompoundOperationWrapper<BlockHash> {
        do {
            let connection = try runtimeConnectionStore.getConnection()

            let blockHashWrapper = blockHashOperationFactory.createBestBlockHashWrapper(
                connection: connection
            )

            let mappingOperation = ClosureOperation<BlockHash> {
                try blockHashWrapper.targetOperation
                    .extractNoCancellableResultData()
                    .toHex(includePrefix: true)
            }

            mappingOperation.addDependency(blockHashWrapper.targetOperation)

            return blockHashWrapper.insertingTail(operation: mappingOperation)
        } catch {
            return CompoundOperationWrapper.createWithError(error)
        }
    }

    func createStakeInfoWrapper(
        for coldkey: AccountId,
        blockHash: BlockHash?
    ) -> CompoundOperationWrapper<[SubtensorStakingPallet.StakeInfo]> {
        createWrapper(
            path: SubtensorStakingPallet.stakeInfoForColdkeyApi,
            blockHash: blockHash,
            paramsClosure: { runtimeApi, encoder, context in
                let paramsCount = runtimeApi.method.inputs.count
                guard paramsCount == 1 else {
                    throw SubstrateRuntimeApiOperationFactoryError.unexpectedParamsCount
                }

                try encoder.append(
                    BytesCodable(wrappedValue: coldkey),
                    ofType: runtimeApi.method.inputs[0].paramType.asTypeId(),
                    with: context.toRawContext()
                )
            }
        )
    }

    func createStakeAvailabilityWrapper(
        for coldkeys: [AccountId],
        netuids: [UInt16]?,
        blockHash: BlockHash?
    ) -> CompoundOperationWrapper<[SubtensorStakingPallet.ColdkeyStakeAvailability]> {
        createWrapper(
            path: SubtensorStakingPallet.stakeAvailabilityForColdkeysApi,
            blockHash: blockHash,
            paramsClosure: { runtimeApi, encoder, context in
                let paramsCount = runtimeApi.method.inputs.count
                guard paramsCount == 2 else {
                    throw SubstrateRuntimeApiOperationFactoryError.unexpectedParamsCount
                }

                try encoder.append(
                    coldkeys.map { BytesCodable(wrappedValue: $0) },
                    ofType: runtimeApi.method.inputs[0].paramType.asTypeId(),
                    with: context.toRawContext()
                )

                let netuidsTypeId = runtimeApi.method.inputs[1].paramType.asTypeId()

                if let netuids {
                    try encoder.append(
                        netuids.map { StringScaleMapper(value: $0) },
                        ofType: netuidsTypeId,
                        with: context.toRawContext()
                    )
                } else {
                    try encoder.append(json: .null, type: netuidsTypeId)
                }
            }
        )
    }

    func createAllDynamicInfoWrapper(
        at blockHash: BlockHash?
    ) -> CompoundOperationWrapper<[SubtensorStakingPallet.DynamicInfo?]> {
        createWrapper(
            path: SubtensorStakingPallet.allDynamicInfoApi,
            blockHash: blockHash,
            paramsClosure: nil
        )
    }

    func createDelegatesWrapper(
        at blockHash: BlockHash?
    ) -> CompoundOperationWrapper<[SubtensorStakingPallet.DelegateInfo]> {
        createWrapper(
            path: SubtensorStakingPallet.delegatesApi,
            blockHash: blockHash,
            paramsClosure: nil
        )
    }

    func createAlphaPricesWrapper(
        at blockHash: BlockHash?
    ) -> CompoundOperationWrapper<[SubtensorStakingPallet.SubnetPrice]> {
        createWrapper(
            path: SubtensorStakingPallet.alphaPriceAllApi,
            blockHash: blockHash,
            paramsClosure: nil
        )
    }

    func createRootBasketOwedWrapper(
        for coldkey: AccountId,
        blockHash: BlockHash?
    ) -> CompoundOperationWrapper<Balance> {
        let owedWrapper: CompoundOperationWrapper<StringScaleMapper<Balance>> = createWrapper(
            path: SubtensorStakingPallet.rootBasketOwedApi,
            blockHash: blockHash,
            paramsClosure: createAccountParamsClosure(for: coldkey)
        )

        let mappingOperation = ClosureOperation<Balance> {
            try owedWrapper.targetOperation.extractNoCancellableResultData().value
        }

        mappingOperation.addDependency(owedWrapper.targetOperation)

        return owedWrapper.insertingTail(operation: mappingOperation)
    }

    func createRootBasketPositionsWrapper(
        for coldkey: AccountId,
        blockHash: BlockHash?
    ) -> CompoundOperationWrapper<[SubtensorStakingPallet.RootBasketPosition]> {
        createWrapper(
            path: SubtensorStakingPallet.rootBasketPositionsApi,
            blockHash: blockHash,
            paramsClosure: createAccountParamsClosure(for: coldkey)
        )
    }
}
