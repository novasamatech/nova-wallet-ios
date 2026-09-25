import Foundation
import Operation_iOS
import SubstrateSdk

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

    func createAlphaPriceWrapper(
        for netuid: UInt16,
        blockHash: BlockHash?
    ) -> CompoundOperationWrapper<Balance>

    func createSimSwapTaoForAlphaWrapper(
        netuid: UInt16,
        taoAmount: Balance,
        blockHash: BlockHash?
    ) -> CompoundOperationWrapper<SubtensorStakingPallet.SimSwapResult>

    func createSimSwapAlphaForTaoWrapper(
        netuid: UInt16,
        alphaAmount: Balance,
        blockHash: BlockHash?
    ) -> CompoundOperationWrapper<SubtensorStakingPallet.SimSwapResult>

    func createFeeRateWrapper(
        for netuid: UInt16,
        blockHash: BlockHash?
    ) -> CompoundOperationWrapper<UInt16>

    /// nil when the chain-wide ValueQuery key is unset, so the caller applies the runtime default
    func createSubnetOwnerCutWrapper(
        blockHash: BlockHash?
    ) -> CompoundOperationWrapper<UInt16?>

    func createSubtokenEnabledWrapper(
        for netuids: [UInt16],
        blockHash: BlockHash?
    ) -> CompoundOperationWrapper<Set<UInt16>>

    func createRootBasketOwedWrapper(
        for coldkey: AccountId,
        blockHash: BlockHash?
    ) -> CompoundOperationWrapper<Balance>

    func createRootBasketPositionsWrapper(
        for coldkey: AccountId,
        blockHash: BlockHash?
    ) -> CompoundOperationWrapper<[SubtensorStakingPallet.RootBasketPosition]>

    func createRootClaimPreviewsWrapper(
        coldkey: AccountId,
        blockHash: BlockHash?
    ) -> CompoundOperationWrapper<[SubtensorStakingPallet.BasketClaimPreview]>

    /// network-wide basket NAV, the observable the spec §6.2 root APY gate samples across blocks
    func createRootBasketTotalNavWrapper(
        at blockHash: BlockHash?
    ) -> CompoundOperationWrapper<Balance>
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

    func createSubnetOwnerCutWrapper() -> CompoundOperationWrapper<UInt16?> {
        createSubnetOwnerCutWrapper(blockHash: nil)
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

    private let requestFactory: StorageRequestFactoryProtocol

    init(
        runtimeConnectionStore: RuntimeConnectionStoring,
        operationQueue: OperationQueue,
        rpcTimeout: Int = JSONRPCTimeout.singleNode
    ) {
        self.runtimeConnectionStore = runtimeConnectionStore
        self.operationQueue = operationQueue

        stateCallFactory = StateCallRequestFactory(rpcTimeout: rpcTimeout)
        requestFactory = StorageRequestFactory.createDefault(with: operationQueue)
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

    private func createNetuidAmountParamsClosure(
        netuid: UInt16,
        amount: Balance
    ) -> StateCallWithApiParamsClosure {
        { runtimeApi, encoder, context in
            let paramsCount = runtimeApi.method.inputs.count
            guard paramsCount == 2 else {
                throw SubstrateRuntimeApiOperationFactoryError.unexpectedParamsCount
            }

            try encoder.append(
                StringScaleMapper(value: netuid),
                ofType: runtimeApi.method.inputs[0].paramType.asTypeId(),
                with: context.toRawContext()
            )

            try encoder.append(
                StringScaleMapper(value: amount),
                ofType: runtimeApi.method.inputs[1].paramType.asTypeId(),
                with: context.toRawContext()
            )
        }
    }

    private func createSimSwapWrapper(
        path: StateCallPath,
        netuid: UInt16,
        amount: Balance,
        blockHash: BlockHash?
    ) -> CompoundOperationWrapper<SubtensorStakingPallet.SimSwapResult> {
        do {
            try SubtensorStakingPallet.ensureU64Amount(amount)
        } catch {
            return CompoundOperationWrapper.createWithError(error)
        }

        return createWrapper(
            path: path,
            blockHash: blockHash,
            paramsClosure: createNetuidAmountParamsClosure(netuid: netuid, amount: amount)
        )
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

    func createAlphaPriceWrapper(
        for netuid: UInt16,
        blockHash: BlockHash?
    ) -> CompoundOperationWrapper<Balance> {
        let priceWrapper: CompoundOperationWrapper<StringScaleMapper<Balance>> = createWrapper(
            path: SubtensorStakingPallet.alphaPriceApi,
            blockHash: blockHash,
            paramsClosure: { runtimeApi, encoder, context in
                let paramsCount = runtimeApi.method.inputs.count
                guard paramsCount == 1 else {
                    throw SubstrateRuntimeApiOperationFactoryError.unexpectedParamsCount
                }

                try encoder.append(
                    StringScaleMapper(value: netuid),
                    ofType: runtimeApi.method.inputs[0].paramType.asTypeId(),
                    with: context.toRawContext()
                )
            }
        )

        let mappingOperation = ClosureOperation<Balance> {
            try priceWrapper.targetOperation.extractNoCancellableResultData().value
        }

        mappingOperation.addDependency(priceWrapper.targetOperation)

        return priceWrapper.insertingTail(operation: mappingOperation)
    }

    func createSimSwapTaoForAlphaWrapper(
        netuid: UInt16,
        taoAmount: Balance,
        blockHash: BlockHash?
    ) -> CompoundOperationWrapper<SubtensorStakingPallet.SimSwapResult> {
        createSimSwapWrapper(
            path: SubtensorStakingPallet.simSwapTaoForAlphaApi,
            netuid: netuid,
            amount: taoAmount,
            blockHash: blockHash
        )
    }

    func createSimSwapAlphaForTaoWrapper(
        netuid: UInt16,
        alphaAmount: Balance,
        blockHash: BlockHash?
    ) -> CompoundOperationWrapper<SubtensorStakingPallet.SimSwapResult> {
        createSimSwapWrapper(
            path: SubtensorStakingPallet.simSwapAlphaForTaoApi,
            netuid: netuid,
            amount: alphaAmount,
            blockHash: blockHash
        )
    }

    func createFeeRateWrapper(
        for netuid: UInt16,
        blockHash: BlockHash?
    ) -> CompoundOperationWrapper<UInt16> {
        do {
            let runtimeProvider = try runtimeConnectionStore.getRuntimeProvider()
            let engine = try runtimeConnectionStore.getConnection()
            let atBlock = try blockHash.map { try Data(hexString: $0) }

            let codingFactoryOperation = runtimeProvider.fetchCoderFactoryOperation()

            let queryWrapper: CompoundOperationWrapper<[StorageResponse<StringScaleMapper<UInt16>>]> =
                requestFactory.queryItems(
                    engine: engine,
                    keyParams: { [StringScaleMapper(value: netuid)] },
                    factory: { try codingFactoryOperation.extractNoCancellableResultData() },
                    storagePath: SubtensorStakingPallet.feeRatePath,
                    options: StorageQueryListOptions(atBlock: atBlock)
                )

            queryWrapper.addDependency(operations: [codingFactoryOperation])

            let mappingOperation = ClosureOperation<UInt16> {
                try queryWrapper.targetOperation.extractNoCancellableResultData()
                    .first?.value?.value ?? SubtensorStakingPallet.defaultFeeRate
            }

            mappingOperation.addDependency(queryWrapper.targetOperation)

            return queryWrapper
                .insertingHead(operations: [codingFactoryOperation])
                .insertingTail(operation: mappingOperation)
        } catch {
            return CompoundOperationWrapper.createWithError(error)
        }
    }

    func createSubnetOwnerCutWrapper(
        blockHash: BlockHash?
    ) -> CompoundOperationWrapper<UInt16?> {
        do {
            let runtimeProvider = try runtimeConnectionStore.getRuntimeProvider()
            let engine = try runtimeConnectionStore.getConnection()
            let atBlock = try blockHash.map { try Data(hexString: $0) }

            let codingFactoryOperation = runtimeProvider.fetchCoderFactoryOperation()

            let queryWrapper: CompoundOperationWrapper<StorageResponse<StringScaleMapper<UInt16>>> =
                requestFactory.queryItem(
                    engine: engine,
                    factory: { try codingFactoryOperation.extractNoCancellableResultData() },
                    storagePath: SubtensorStakingPallet.subnetOwnerCutPath,
                    at: atBlock
                )

            queryWrapper.addDependency(operations: [codingFactoryOperation])

            let mappingOperation = ClosureOperation<UInt16?> {
                try queryWrapper.targetOperation.extractNoCancellableResultData().value?.value
            }

            mappingOperation.addDependency(queryWrapper.targetOperation)

            return queryWrapper
                .insertingHead(operations: [codingFactoryOperation])
                .insertingTail(operation: mappingOperation)
        } catch {
            return CompoundOperationWrapper.createWithError(error)
        }
    }

    func createSubtokenEnabledWrapper(
        for netuids: [UInt16],
        blockHash: BlockHash?
    ) -> CompoundOperationWrapper<Set<UInt16>> {
        do {
            let runtimeProvider = try runtimeConnectionStore.getRuntimeProvider()
            let engine = try runtimeConnectionStore.getConnection()
            let atBlock = try blockHash.map { try Data(hexString: $0) }

            let codingFactoryOperation = runtimeProvider.fetchCoderFactoryOperation()

            let queryWrapper: CompoundOperationWrapper<[StorageResponse<Bool>]> =
                requestFactory.queryItems(
                    engine: engine,
                    keyParams: { netuids.map { StringScaleMapper(value: $0) } },
                    factory: { try codingFactoryOperation.extractNoCancellableResultData() },
                    storagePath: SubtensorStakingPallet.subtokenEnabledPath,
                    options: StorageQueryListOptions(atBlock: atBlock)
                )

            queryWrapper.addDependency(operations: [codingFactoryOperation])

            let mappingOperation = ClosureOperation<Set<UInt16>> {
                let responses = try queryWrapper.targetOperation.extractNoCancellableResultData()

                return zip(netuids, responses).reduce(into: Set<UInt16>()) { accum, pair in
                    if pair.1.value == true {
                        accum.insert(pair.0)
                    }
                }
            }

            mappingOperation.addDependency(queryWrapper.targetOperation)

            return queryWrapper
                .insertingHead(operations: [codingFactoryOperation])
                .insertingTail(operation: mappingOperation)
        } catch {
            return CompoundOperationWrapper.createWithError(error)
        }
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

    func createRootBasketTotalNavWrapper(
        at blockHash: BlockHash?
    ) -> CompoundOperationWrapper<Balance> {
        let navWrapper: CompoundOperationWrapper<StringScaleMapper<Balance>> = createWrapper(
            path: SubtensorStakingPallet.rootBasketTotalNavApi,
            blockHash: blockHash,
            paramsClosure: nil
        )

        let mappingOperation = ClosureOperation<Balance> {
            try navWrapper.targetOperation.extractNoCancellableResultData().value
        }

        mappingOperation.addDependency(navWrapper.targetOperation)

        return navWrapper.insertingTail(operation: mappingOperation)
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

    func createRootClaimPreviewsWrapper(
        coldkey: AccountId,
        blockHash: BlockHash?
    ) -> CompoundOperationWrapper<[SubtensorStakingPallet.BasketClaimPreview]> {
        createWrapper(
            path: SubtensorStakingPallet.rootBasketClaimPreviewsApi,
            blockHash: blockHash,
            paramsClosure: createAccountParamsClosure(for: coldkey)
        )
    }
}
