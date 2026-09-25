import BigInt
@testable import novawallet
import Operation_iOS
import SubstrateSdk
import XCTest

final class SubtensorValidatorChainLiveTests: XCTestCase {
    private let subnetNetuid: UInt16 = 64
    private let keysPath = StorageCodingPath(moduleName: SubtensorStakingPallet.name, itemName: "Keys")

    func testSnapshotOfSeatedSubnetAndRootHotkeysFollowsChainRules() throws {
        let storageFacade = SubstrateStorageTestFacade()
        let chainRegistry = ChainRegistryFacade.setupForIntegrationTest(with: storageFacade)
        let operationQueue = OperationQueue()

        try withExtendedLifetime(chainRegistry) {
            let chainWrapper = chainRegistry.asyncWaitChainWrapper(for: KnowChainId.bittensor)
            operationQueue.addOperations(chainWrapper.allOperations, waitUntilFinished: true)
            _ = try XCTUnwrap(chainWrapper.targetOperation.extractNoCancellableResultData())

            let connectionStore = ChainRegistryRuntimeConnectionStore(
                chainId: KnowChainId.bittensor,
                chainRegistry: chainRegistry
            )

            let factory = SubtensorValidatorChainOperationFactory(runtimeConnectionStore: connectionStore)
            let requestFactory = StorageRequestFactory.createDefault(with: operationQueue)

            let seated = try fetchUidZeroHotkeys(
                netuids: [subnetNetuid, SubtensorStakingPallet.rootNetuid],
                connectionStore: connectionStore,
                requestFactory: requestFactory,
                operationQueue: operationQueue
            )

            let subnetPair = SubtensorHotkeySubnet(hotkey: seated[0], netuid: subnetNetuid)
            let rootPair = SubtensorHotkeySubnet(hotkey: seated[1], netuid: SubtensorStakingPallet.rootNetuid)

            let snapshotWrapper = factory.createChainSnapshotWrapper(
                for: SubtensorValidatorChainQuery(pairs: [subnetPair, rootPair], includesHotkeyAlpha: true)
            )

            operationQueue.addOperations(snapshotWrapper.allOperations, waitUntilFinished: true)
            let snapshot = try snapshotWrapper.targetOperation.extractNoCancellableResultData()

            let subnetStatus = try XCTUnwrap(SubtensorValidatorChainStatus.make(snapshot: snapshot, pair: subnetPair))
            XCTAssertEqual(subnetStatus.uid, 0)
            XCTAssertNotNil(subnetStatus.hasPermit)
            XCTAssertNotNil(subnetStatus.isActive)

            let rootStatus = try XCTUnwrap(SubtensorValidatorChainStatus.make(snapshot: snapshot, pair: rootPair))
            XCTAssertEqual(rootStatus.uid, 0)
            XCTAssertNil(rootStatus.hasPermit)
            XCTAssertNil(rootStatus.blocksSinceUpdate)
            XCTAssertNil(rootStatus.isActive)

            let chainTakes = try fetchTakes(
                hotkeys: seated,
                blockHash: Data(hexString: snapshot.blockHash),
                connectionStore: connectionStore,
                requestFactory: requestFactory,
                operationQueue: operationQueue
            )

            XCTAssertEqual(Set(chainTakes.keys), Set(seated))
            XCTAssertEqual(snapshot.takes, chainTakes)

            for take in snapshot.takes.values {
                let fraction = Decimal(take) / Decimal(SubtensorStakingPallet.perU16Denominator)
                XCTAssertTrue((0 ... 1).contains(fraction))
            }

            let parameters = try fetchCutoffParameters(
                blockHash: Data(hexString: snapshot.blockHash),
                connectionStore: connectionStore,
                requestFactory: requestFactory,
                operationQueue: operationQueue
            )

            XCTAssertEqual(snapshot.effectiveActivityCutoffs[subnetNetuid], parameters.factor * parameters.tempo / 1000)
            XCTAssertNil(snapshot.effectiveActivityCutoffs[SubtensorStakingPallet.rootNetuid])
            XCTAssertEqual(snapshot.permits[subnetNetuid]?.count, snapshot.lastUpdates[subnetNetuid]?.count)
        }
    }

    private func fetchUidZeroHotkeys(
        netuids: [UInt16],
        connectionStore: RuntimeConnectionStoring,
        requestFactory: StorageRequestFactoryProtocol,
        operationQueue: OperationQueue
    ) throws -> [AccountId] {
        let codingFactoryOperation = try connectionStore.getRuntimeProvider().fetchCoderFactoryOperation()

        let wrapper: CompoundOperationWrapper<[StorageResponse<BytesCodable>]> = try requestFactory.queryItems(
            engine: connectionStore.getConnection(),
            keyParams1: { netuids.map { StringScaleMapper(value: $0) } },
            keyParams2: { netuids.map { _ in StringScaleMapper(value: UInt16(0)) } },
            factory: { try codingFactoryOperation.extractNoCancellableResultData() },
            storagePath: keysPath,
            options: StorageQueryListOptions()
        )

        wrapper.addDependency(operations: [codingFactoryOperation])

        operationQueue.addOperations([codingFactoryOperation] + wrapper.allOperations, waitUntilFinished: true)

        let hotkeys = try wrapper.targetOperation.extractNoCancellableResultData().map { response -> AccountId in
            XCTAssertNotNil(response.data)

            return try XCTUnwrap(response.value?.wrappedValue)
        }

        XCTAssertEqual(hotkeys.count, netuids.count)

        return hotkeys
    }

    private func fetchCutoffParameters(
        blockHash: Data,
        connectionStore: RuntimeConnectionStoring,
        requestFactory: StorageRequestFactoryProtocol,
        operationQueue: OperationQueue
    ) throws -> (factor: UInt64, tempo: UInt64) {
        let codingFactoryOperation = try connectionStore.getRuntimeProvider().fetchCoderFactoryOperation()
        let engine = try connectionStore.getConnection()
        let netuid = subnetNetuid

        let tempoWrapper: CompoundOperationWrapper<[StorageResponse<StringScaleMapper<UInt16>>]> =
            requestFactory.queryItems(
                engine: engine,
                keyParams: { [StringScaleMapper(value: netuid)] },
                factory: { try codingFactoryOperation.extractNoCancellableResultData() },
                storagePath: SubtensorStakingPallet.tempoPath,
                options: StorageQueryListOptions(atBlock: blockHash)
            )

        let factorWrapper: CompoundOperationWrapper<[StorageResponse<StringScaleMapper<UInt32>>]> =
            requestFactory.queryItems(
                engine: engine,
                keyParams: { [StringScaleMapper(value: netuid)] },
                factory: { try codingFactoryOperation.extractNoCancellableResultData() },
                storagePath: SubtensorStakingPallet.activityCutoffFactorMilliPath,
                options: StorageQueryListOptions(atBlock: blockHash)
            )

        tempoWrapper.addDependency(operations: [codingFactoryOperation])
        factorWrapper.addDependency(operations: [codingFactoryOperation])

        operationQueue.addOperations(
            [codingFactoryOperation] + tempoWrapper.allOperations + factorWrapper.allOperations,
            waitUntilFinished: true
        )

        let tempo = try XCTUnwrap(tempoWrapper.targetOperation.extractNoCancellableResultData().first?.value?.value)
        let factor = try XCTUnwrap(factorWrapper.targetOperation.extractNoCancellableResultData().first?.value?.value)

        return (UInt64(factor), UInt64(tempo))
    }

    private func fetchTakes(
        hotkeys: [AccountId],
        blockHash: Data,
        connectionStore: RuntimeConnectionStoring,
        requestFactory: StorageRequestFactoryProtocol,
        operationQueue: OperationQueue
    ) throws -> [AccountId: UInt16] {
        let codingFactoryOperation = try connectionStore.getRuntimeProvider().fetchCoderFactoryOperation()

        let wrapper: CompoundOperationWrapper<[StorageResponse<StringScaleMapper<UInt16>>]> =
            try requestFactory.queryItems(
                engine: connectionStore.getConnection(),
                keyParams: { hotkeys.map { BytesCodable(wrappedValue: $0) } },
                factory: { try codingFactoryOperation.extractNoCancellableResultData() },
                storagePath: SubtensorStakingPallet.delegatesTakePath,
                options: StorageQueryListOptions(atBlock: blockHash)
            )

        wrapper.addDependency(operations: [codingFactoryOperation])

        operationQueue.addOperations([codingFactoryOperation] + wrapper.allOperations, waitUntilFinished: true)

        return try zip(hotkeys, wrapper.targetOperation.extractNoCancellableResultData())
            .reduce(into: [AccountId: UInt16]()) { result, item in
                result[item.0] = item.1.value?.value
            }
    }
}
