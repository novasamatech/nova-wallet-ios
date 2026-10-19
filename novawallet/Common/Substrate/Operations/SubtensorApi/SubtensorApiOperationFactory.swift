import Foundation
import Operation_iOS
import SubstrateSdk

protocol SubtensorApiOperationFactoryProtocol {
    func createBestBlockHashWrapper() -> CompoundOperationWrapper<BlockHash>

    func createStakeInfoWrapper(
        for coldkey: AccountId,
        blockHash: BlockHash?
    ) -> CompoundOperationWrapper<[SubtensorPallet.StakeInfo]>

    func createStakeAvailabilityWrapper(
        for coldkeys: [AccountId],
        netuids: [UInt16],
        blockHash: BlockHash?
    ) -> CompoundOperationWrapper<[SubtensorPallet.ColdkeyStakeAvailability]>

    func createAllDynamicInfoWrapper(
        at blockHash: BlockHash?
    ) -> CompoundOperationWrapper<[SubtensorPallet.DynamicInfo?]>

    func createDynamicInfoWrapper(for netuid: UInt16) -> CompoundOperationWrapper<SubtensorPallet.DynamicInfo?>

    func createDelegateWrapper(
        for hotkey: AccountId,
        blockHash: BlockHash?
    ) -> CompoundOperationWrapper<SubtensorPallet.DelegateInfo?>

    func createAlphaPricesWrapper() -> CompoundOperationWrapper<[SubtensorPallet.SubnetPrice]>

    func createAlphaPriceWrapper(
        for netuid: UInt16,
        blockHash: BlockHash?
    ) -> CompoundOperationWrapper<Balance>

    func createSimSwapTaoForAlphaWrapper(
        netuid: UInt16,
        taoAmount: Balance,
        blockHash: BlockHash?
    ) -> CompoundOperationWrapper<SubtensorPallet.SimSwapResult>

    func createSimSwapAlphaForTaoWrapper(
        netuid: UInt16,
        alphaAmount: Balance,
        blockHash: BlockHash?
    ) -> CompoundOperationWrapper<SubtensorPallet.SimSwapResult>

    func createFeeRateWrapper(
        for netuid: UInt16,
        blockHash: BlockHash?
    ) -> CompoundOperationWrapper<UInt16>

    func createSubtokenEnabledWrapper(for netuids: [UInt16]) -> CompoundOperationWrapper<Set<UInt16>>

    func createRootClaimPreviewsWrapper(
        coldkey: AccountId,
        blockHash: BlockHash?
    ) -> CompoundOperationWrapper<[SubtensorPallet.BasketClaimPreview]>

    func createRootClaimableThresholdWrapper(
        blockHash: BlockHash?
    ) -> CompoundOperationWrapper<SubtensorPallet.FixedPoint96F32?>
}

final class SubtensorApiOperationFactory {
    let runtimeConnectionStore: RuntimeConnectionStoring
    let operationQueue: OperationQueue

    let stateCallFactory = StateCallRequestFactory()
    let blockHashOperationFactory = BlockHashOperationFactory()

    private let requestFactory: StorageRequestFactoryProtocol

    init(runtimeConnectionStore: RuntimeConnectionStoring, operationQueue: OperationQueue) {
        self.runtimeConnectionStore = runtimeConnectionStore
        self.operationQueue = operationQueue

        requestFactory = StorageRequestFactory.createDefault(with: operationQueue)
    }

    private func createSingleParamClosure<P: Encodable>(_ param: P) -> StateCallWithApiParamsClosure {
        { runtimeApi, encoder, context in
            let paramsCount = runtimeApi.method.inputs.count
            guard paramsCount == 1 else {
                throw SubstrateRuntimeApiOperationFactoryError.unexpectedParamsCount
            }

            try encoder.append(
                param,
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
    ) -> CompoundOperationWrapper<SubtensorPallet.SimSwapResult> {
        do {
            try SubtensorPallet.ensureU64Amount(amount)
        } catch {
            return CompoundOperationWrapper.createWithError(error)
        }

        return createWrapper(
            path: path,
            blockHash: blockHash,
            paramsClosure: createNetuidAmountParamsClosure(netuid: netuid, amount: amount)
        )
    }

    private func createStorageWrapper<Q, R>(
        blockHash: BlockHash?,
        query: (JSONRPCEngine, @escaping () throws -> RuntimeCoderFactoryProtocol, Data?)
            -> CompoundOperationWrapper<Q>,
        mapping: @escaping (Q) throws -> R
    ) -> CompoundOperationWrapper<R> {
        do {
            let runtimeProvider = try runtimeConnectionStore.getRuntimeProvider()
            let engine = try runtimeConnectionStore.getConnection()
            let atBlock = try blockHash.map { try Data(hexString: $0) }

            let codingFactoryOperation = runtimeProvider.fetchCoderFactoryOperation()

            let queryWrapper = query(engine, { try codingFactoryOperation.extractNoCancellableResultData() }, atBlock)

            queryWrapper.addDependency(operations: [codingFactoryOperation])

            return queryWrapper.insertingHead(operations: [codingFactoryOperation]).mapped(mapping)
        } catch {
            return CompoundOperationWrapper.createWithError(error)
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

            return blockHashWrapper.mapped { $0.toHex(includePrefix: true) }
        } catch {
            return CompoundOperationWrapper.createWithError(error)
        }
    }

    func createStakeInfoWrapper(
        for coldkey: AccountId,
        blockHash: BlockHash?
    ) -> CompoundOperationWrapper<[SubtensorPallet.StakeInfo]> {
        createWrapper(
            path: SubtensorPallet.stakeInfoForColdkeyApi,
            blockHash: blockHash,
            paramsClosure: createSingleParamClosure(BytesCodable(wrappedValue: coldkey))
        )
    }

    func createStakeAvailabilityWrapper(
        for coldkeys: [AccountId],
        netuids: [UInt16],
        blockHash: BlockHash?
    ) -> CompoundOperationWrapper<[SubtensorPallet.ColdkeyStakeAvailability]> {
        createWrapper(
            path: SubtensorPallet.stakeAvailabilityForColdkeysApi,
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

                try encoder.append(
                    netuids.map { StringScaleMapper(value: $0) },
                    ofType: runtimeApi.method.inputs[1].paramType.asTypeId(),
                    with: context.toRawContext()
                )
            }
        )
    }

    func createAllDynamicInfoWrapper(
        at blockHash: BlockHash?
    ) -> CompoundOperationWrapper<[SubtensorPallet.DynamicInfo?]> {
        createWrapper(
            path: SubtensorPallet.allDynamicInfoApi,
            blockHash: blockHash,
            paramsClosure: nil
        )
    }

    func createDynamicInfoWrapper(for netuid: UInt16) -> CompoundOperationWrapper<SubtensorPallet.DynamicInfo?> {
        createWrapper(
            path: SubtensorPallet.dynamicInfoApi,
            blockHash: nil,
            paramsClosure: createSingleParamClosure(StringScaleMapper(value: netuid))
        )
    }

    func createDelegateWrapper(
        for hotkey: AccountId,
        blockHash: BlockHash?
    ) -> CompoundOperationWrapper<SubtensorPallet.DelegateInfo?> {
        createWrapper(
            path: SubtensorPallet.delegateApi,
            blockHash: blockHash,
            paramsClosure: createSingleParamClosure(BytesCodable(wrappedValue: hotkey))
        )
    }

    func createAlphaPricesWrapper() -> CompoundOperationWrapper<[SubtensorPallet.SubnetPrice]> {
        createWrapper(path: SubtensorPallet.alphaPriceAllApi, blockHash: nil, paramsClosure: nil)
    }

    func createAlphaPriceWrapper(
        for netuid: UInt16,
        blockHash: BlockHash?
    ) -> CompoundOperationWrapper<Balance> {
        let priceWrapper: CompoundOperationWrapper<StringScaleMapper<Balance>> = createWrapper(
            path: SubtensorPallet.alphaPriceApi,
            blockHash: blockHash,
            paramsClosure: createSingleParamClosure(StringScaleMapper(value: netuid))
        )

        return priceWrapper.mapped { $0.value }
    }

    func createSimSwapTaoForAlphaWrapper(
        netuid: UInt16,
        taoAmount: Balance,
        blockHash: BlockHash?
    ) -> CompoundOperationWrapper<SubtensorPallet.SimSwapResult> {
        createSimSwapWrapper(
            path: SubtensorPallet.simSwapTaoForAlphaApi,
            netuid: netuid,
            amount: taoAmount,
            blockHash: blockHash
        )
    }

    func createSimSwapAlphaForTaoWrapper(
        netuid: UInt16,
        alphaAmount: Balance,
        blockHash: BlockHash?
    ) -> CompoundOperationWrapper<SubtensorPallet.SimSwapResult> {
        createSimSwapWrapper(
            path: SubtensorPallet.simSwapAlphaForTaoApi,
            netuid: netuid,
            amount: alphaAmount,
            blockHash: blockHash
        )
    }

    func createFeeRateWrapper(
        for netuid: UInt16,
        blockHash: BlockHash?
    ) -> CompoundOperationWrapper<UInt16> {
        createStorageWrapper(
            blockHash: blockHash,
            query: { engine, factory, atBlock in
                self.requestFactory.queryItems(
                    engine: engine,
                    keyParams: { [StringScaleMapper(value: netuid)] },
                    factory: factory,
                    storagePath: SubtensorPallet.feeRatePath,
                    options: StorageQueryListOptions(atBlock: atBlock)
                )
            },
            mapping: { (responses: [StorageResponse<StringScaleMapper<UInt16>>]) in
                responses.first?.value?.value ?? SubtensorPallet.defaultFeeRate
            }
        )
    }

    func createSubtokenEnabledWrapper(for netuids: [UInt16]) -> CompoundOperationWrapper<Set<UInt16>> {
        createStorageWrapper(
            blockHash: nil,
            query: { engine, factory, atBlock in
                self.requestFactory.queryItems(
                    engine: engine,
                    keyParams: { netuids.map { StringScaleMapper(value: $0) } },
                    factory: factory,
                    storagePath: SubtensorPallet.subtokenEnabledPath,
                    options: StorageQueryListOptions(atBlock: atBlock)
                )
            },
            mapping: { (responses: [StorageResponse<Bool>]) in
                zip(netuids, responses).reduce(into: Set<UInt16>()) { accum, pair in
                    if pair.1.value == true {
                        accum.insert(pair.0)
                    }
                }
            }
        )
    }

    func createRootClaimPreviewsWrapper(
        coldkey: AccountId,
        blockHash: BlockHash?
    ) -> CompoundOperationWrapper<[SubtensorPallet.BasketClaimPreview]> {
        createWrapper(
            path: SubtensorPallet.rootBasketClaimPreviewsApi,
            blockHash: blockHash,
            paramsClosure: createSingleParamClosure(BytesCodable(wrappedValue: coldkey))
        )
    }

    func createRootClaimableThresholdWrapper(
        blockHash: BlockHash?
    ) -> CompoundOperationWrapper<SubtensorPallet.FixedPoint96F32?> {
        createStorageWrapper(
            blockHash: blockHash,
            query: { engine, factory, atBlock in
                self.requestFactory.queryItems(
                    engine: engine,
                    keyParams: { [StringScaleMapper(value: SubtensorPallet.rootNetuid)] },
                    factory: factory,
                    storagePath: SubtensorPallet.rootClaimableThresholdPath,
                    options: StorageQueryListOptions(atBlock: atBlock)
                )
            },
            mapping: { (responses: [StorageResponse<SubtensorPallet.FixedPoint96F32>]) in
                responses.first?.value
            }
        )
    }
}
