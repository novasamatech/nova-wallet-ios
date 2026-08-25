import Foundation
import SubstrateSdk
import Operation_iOS

protocol SubtensorApiOperationFactoryProtocol {
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
}

extension SubtensorApiOperationFactoryProtocol {
    func createStakeInfoWrapper(for coldkey: AccountId) -> CompoundOperationWrapper<[SubtensorStakingPallet.StakeInfo]> {
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
}

final class SubtensorApiOperationFactory {
    let runtimeConnectionStore: RuntimeConnectionStoring
    let operationQueue: OperationQueue

    let stateCallFactory = StateCallRequestFactory()

    init(runtimeConnectionStore: RuntimeConnectionStoring, operationQueue: OperationQueue) {
        self.runtimeConnectionStore = runtimeConnectionStore
        self.operationQueue = operationQueue
    }

    private func createNoParamsWrapper<R: Decodable>(
        path: StateCallPath,
        blockHash: BlockHash?
    ) -> CompoundOperationWrapper<R> {
        do {
            let runtimeProvider = try runtimeConnectionStore.getRuntimeProvider()
            let connection = try runtimeConnectionStore.getConnection()

            return stateCallFactory.createWrapper(
                path: path,
                paramsClosure: nil,
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
    func createStakeInfoWrapper(
        for coldkey: AccountId,
        blockHash: BlockHash?
    ) -> CompoundOperationWrapper<[SubtensorStakingPallet.StakeInfo]> {
        do {
            let runtimeProvider = try runtimeConnectionStore.getRuntimeProvider()
            let connection = try runtimeConnectionStore.getConnection()

            return stateCallFactory.createWrapper(
                path: SubtensorStakingPallet.stakeInfoForColdkeyApi,
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
                },
                runtimeProvider: runtimeProvider,
                connection: connection,
                operationQueue: operationQueue,
                at: blockHash
            )
        } catch {
            return CompoundOperationWrapper.createWithError(error)
        }
    }

    func createStakeAvailabilityWrapper(
        for coldkeys: [AccountId],
        netuids: [UInt16]?,
        blockHash: BlockHash?
    ) -> CompoundOperationWrapper<[SubtensorStakingPallet.ColdkeyStakeAvailability]> {
        do {
            let runtimeProvider = try runtimeConnectionStore.getRuntimeProvider()
            let connection = try runtimeConnectionStore.getConnection()

            return stateCallFactory.createWrapper(
                path: SubtensorStakingPallet.stakeAvailabilityForColdkeysApi,
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
                },
                runtimeProvider: runtimeProvider,
                connection: connection,
                operationQueue: operationQueue,
                at: blockHash
            )
        } catch {
            return CompoundOperationWrapper.createWithError(error)
        }
    }

    func createAllDynamicInfoWrapper(
        at blockHash: BlockHash?
    ) -> CompoundOperationWrapper<[SubtensorStakingPallet.DynamicInfo?]> {
        createNoParamsWrapper(path: SubtensorStakingPallet.allDynamicInfoApi, blockHash: blockHash)
    }

    func createDelegatesWrapper(
        at blockHash: BlockHash?
    ) -> CompoundOperationWrapper<[SubtensorStakingPallet.DelegateInfo]> {
        createNoParamsWrapper(path: SubtensorStakingPallet.delegatesApi, blockHash: blockHash)
    }

    func createAlphaPricesWrapper(
        at blockHash: BlockHash?
    ) -> CompoundOperationWrapper<[SubtensorStakingPallet.SubnetPrice]> {
        createNoParamsWrapper(path: SubtensorStakingPallet.alphaPriceAllApi, blockHash: blockHash)
    }
}
