import Foundation
import Operation_iOS
import SubstrateSdk
import Keystore_iOS

final class AuraEraOperationFactory: EraCountdownOperationFactoryProtocol {
    let storageRequestFactory: StorageRequestFactoryProtocol
    let blockTimeService: BlockTimeEstimationServiceProtocol
    let blockTimeOperationFactory: BlockTimeOperationFactoryProtocol
    let sessionPeriodOperationFactory: StakingSessionPeriodOperationFactoryProtocol

    init(
        storageRequestFactory: StorageRequestFactoryProtocol,
        blockTimeService: BlockTimeEstimationServiceProtocol,
        blockTimeOperationFactory: BlockTimeOperationFactoryProtocol,
        sessionPeriodOperationFactory: StakingSessionPeriodOperationFactoryProtocol
    ) {
        self.storageRequestFactory = storageRequestFactory
        self.blockTimeService = blockTimeService
        self.blockTimeOperationFactory = blockTimeOperationFactory
        self.sessionPeriodOperationFactory = sessionPeriodOperationFactory
    }

    // swiftlint:disable function_body_length
    func fetchCountdownOperationWrapper(
        for connection: JSONRPCEngine,
        runtimeService: RuntimeCodingServiceProtocol
    ) -> CompoundOperationWrapper<EraCountdown> {
        let codingFactoryOperation = runtimeService.fetchCoderFactoryOperation()
        let keyFactory = StorageKeyFactory()

        let eraLengthWrapper: CompoundOperationWrapper<SessionIndex> = createFetchConstantWrapper(
            for: .eraLength,
            codingFactoryOperation: codingFactoryOperation
        )

        let sessionLengthOperation: BaseOperation<SessionIndex> = sessionPeriodOperationFactory.createOperation(
            dependingOn: codingFactoryOperation
        )

        let blockTimeWrapper = blockTimeOperationFactory.createBlockTimeOperation(
            from: runtimeService,
            blockTimeEstimationService: blockTimeService
        )

        let sessionIndexWrapper: CompoundOperationWrapper<[StorageResponse<StringScaleMapper<SessionIndex>>]> =
            storageRequestFactory.queryItems(
                engine: connection,
                keys: { [try keyFactory.key(from: .currentSessionIndex)] },
                factory: { try codingFactoryOperation.extractNoCancellableResultData() },
                storagePath: .currentSessionIndex
            )

        let blockNumberWrapper: CompoundOperationWrapper<[StorageResponse<StringScaleMapper<BlockNumber>>]> =
            storageRequestFactory.queryItems(
                engine: connection,
                keys: { [try keyFactory.key(from: SystemPallet.blockNumberPath)] },
                factory: { try codingFactoryOperation.extractNoCancellableResultData() },
                storagePath: SystemPallet.blockNumberPath
            )

        let activeEraWrapper: CompoundOperationWrapper<[StorageResponse<ActiveEraInfo>]> =
            storageRequestFactory.queryItems(
                engine: connection,
                keys: { [try keyFactory.key(from: Staking.activeEra)] },
                factory: { try codingFactoryOperation.extractNoCancellableResultData() },
                storagePath: Staking.activeEra
            )

        let currentEraWrapper: CompoundOperationWrapper<[StorageResponse<StringScaleMapper<EraIndex>>]> =
            storageRequestFactory.queryItems(
                engine: connection,
                keys: { [try keyFactory.key(from: Staking.currentEra)] },
                factory: { try codingFactoryOperation.extractNoCancellableResultData() },
                storagePath: Staking.currentEra
            )

        let startSessionWrapper = createEraStartSessionIndex(
            dependingOn: activeEraWrapper.targetOperation,
            codingFactoryOperation: codingFactoryOperation,
            engine: connection
        )

        let singleOperations: [Operation] = [sessionLengthOperation]

        let dependencies = singleOperations
            + eraLengthWrapper.allOperations
            + blockTimeWrapper.allOperations
            + sessionIndexWrapper.allOperations
            + blockNumberWrapper.allOperations
            + activeEraWrapper.allOperations
            + currentEraWrapper.allOperations
            + startSessionWrapper.allOperations
        dependencies.forEach { $0.addDependency(codingFactoryOperation) }

        let mergeOperation = ClosureOperation<EraCountdown> {
            guard
                let activeEra = try? activeEraWrapper.targetOperation.extractNoCancellableResultData()
                .first?.value?.index,
                let currentEra = try? currentEraWrapper.targetOperation.extractNoCancellableResultData()
                .first?.value?.value,
                let eraLength = try? eraLengthWrapper.targetOperation.extractNoCancellableResultData(),
                let sessionLength = try? sessionLengthOperation.extractNoCancellableResultData(),
                let blockTime = try? blockTimeWrapper.targetOperation.extractNoCancellableResultData(),
                let currentSessionIndex = try? sessionIndexWrapper.targetOperation
                .extractNoCancellableResultData().first?.value?.value,
                let currentSlot = try? blockNumberWrapper.targetOperation
                .extractNoCancellableResultData().first?.value?.value,
                let eraStartSessionIndex = try? startSessionWrapper.targetOperation
                .extractNoCancellableResultData().first?.value?.value
            else {
                throw EraCountdownOperationFactoryError.noData
            }

            return EraCountdown(
                activeEra: activeEra,
                currentEra: currentEra,
                eraLength: eraLength,
                sessionLength: sessionLength,
                activeEraStartSessionIndex: eraStartSessionIndex,
                currentSessionIndex: currentSessionIndex,
                currentEpochIndex: EpochIndex(currentSessionIndex),
                currentSlot: Slot(currentSlot),
                genesisSlot: 0,
                blockCreationTime: Moment(blockTime),
                createdAtDate: Date()
            )
        }

        dependencies.forEach { mergeOperation.addDependency($0) }

        return CompoundOperationWrapper(
            targetOperation: mergeOperation,
            dependencies: dependencies + [codingFactoryOperation]
        )
    }

    private func createEraStartSessionIndex(
        dependingOn activeEra: BaseOperation<[StorageResponse<ActiveEraInfo>]>,
        codingFactoryOperation: BaseOperation<RuntimeCoderFactoryProtocol>,
        engine: JSONRPCEngine
    ) -> CompoundOperationWrapper<[StorageResponse<StringScaleMapper<SessionIndex>>]> {
        let keyParams: () throws -> [StringScaleMapper<EraIndex>] = {
            let activeEraIndex = try activeEra.extractNoCancellableResultData().first?.value?.index ?? 0
            return [StringScaleMapper(value: activeEraIndex)]
        }

        let wrapper: CompoundOperationWrapper<[StorageResponse<StringScaleMapper<SessionIndex>>]> =
            storageRequestFactory.queryItems(
                engine: engine,
                keyParams: keyParams,
                factory: { try codingFactoryOperation.extractNoCancellableResultData() },
                storagePath: Staking.eraStartSessionIndex
            )
        wrapper.addDependency(operations: [activeEra])

        return wrapper
    }

    private func createFetchConstantWrapper<T: LosslessStringConvertible & Equatable>(
        for path: ConstantCodingPath,
        codingFactoryOperation: BaseOperation<RuntimeCoderFactoryProtocol>,
        fallbackValue: T? = nil
    ) -> CompoundOperationWrapper<T> {
        let constOperation = PrimitiveConstantOperation<T>(path: path, fallbackValue: fallbackValue)
        constOperation.configurationBlock = {
            do {
                constOperation.codingFactory = try codingFactoryOperation.extractNoCancellableResultData()
            } catch {
                constOperation.result = .failure(error)
            }
        }

        return CompoundOperationWrapper(targetOperation: constOperation)
    }
}
