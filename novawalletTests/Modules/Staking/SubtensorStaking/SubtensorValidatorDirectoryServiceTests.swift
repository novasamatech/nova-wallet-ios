import Cuckoo
@testable import novawallet
import Operation_iOS
import SubstrateSdk
import XCTest

final class SubtensorValidatorDirectoryServiceTests: XCTestCase {
    private typealias ValidatorsResult = BittensorApiResult<BittensorApi.ValidatorCollection>

    private let subnet = SubtensorSubnetRef(netuid: 64, registeredAt: 4_531_295)
    private let root = SubtensorSubnetRef(netuid: 0, registeredAt: 0)
    private let head: BlockNumber = 9_140_000
    private let olderAsOf = Date(timeIntervalSince1970: 1_790_000_000)
    private let newerAsOf = Date(timeIntervalSince1970: 1_790_000_300)
    private let hotkeyA = Data(repeating: 0x0A, count: 32)
    private let hotkeyB = Data(repeating: 0x0B, count: 32)
    private let hotkeyC = Data(repeating: 0x0C, count: 32)

    func testDirectoryMergesBackendRowsWithChainValuesInBackendOrder() throws {
        let apiFactory = MockBittensorApiOperationFactoryProtocol()
        let chainFactory = MockSubtensorValidatorChainOperationFactoryProtocol()

        var world = ChainWorld(head: head)
        world.seat(hotkeyA, netuid: 64, uid: 5, blocksSinceUpdate: 100)
        world.seat(hotkeyB, netuid: 64, uid: 9, blocksSinceUpdate: 10)
        world.takes[hotkeyB] = 6553
        world.alpha[pair(hotkeyA, 64)] = 1_000_000_000
        world.alpha[pair(hotkeyB, 64)] = 2_000_000_000

        try stubValidators(apiFactory, result: makeCollection(
            rows: [
                row(hotkeyA, identity: "  Aster Stake ", stake: "Aster"),
                row(hotkeyB, identity: nil, stake: " BlueHarbor "),
                ValidatorRow(hotkey: "not-an-address", identity: "Broken", stake: nil, metagraphUid: 3),
                row(hotkeyC, identity: "   ", stake: nil)
            ],
            stakes: available(olderAsOf, .fresh),
            metagraph: available(newerAsOf, .stale),
            identities: available(newerAsOf, .fresh)
        ))

        stubChain(chainFactory, world: world)

        let service = makeService(apiFactory: apiFactory, chainFactory: chainFactory)

        let directory = try run(service.createDirectoryWrapper(for: subnet))

        let expected = SubtensorValidatorDirectory(
            subnet: subnet,
            items: [
                SubtensorValidatorDirectoryItem(
                    hotkey: hotkeyA,
                    netuid: 64,
                    name: "Aster Stake",
                    take: takeFraction(11796),
                    reportedStake: BigRational(numerator: 1000, denominator: 1),
                    status: SubtensorValidatorChainStatus(uid: 5, hasPermit: true, blocksSinceUpdate: 100, isActive: true)
                ),
                SubtensorValidatorDirectoryItem(
                    hotkey: hotkeyB,
                    netuid: 64,
                    name: "BlueHarbor",
                    take: takeFraction(6553),
                    reportedStake: BigRational(numerator: 1000, denominator: 1),
                    status: SubtensorValidatorChainStatus(uid: 9, hasPermit: true, blocksSinceUpdate: 10, isActive: true)
                ),
                SubtensorValidatorDirectoryItem(
                    hotkey: hotkeyC,
                    netuid: 64,
                    name: nil,
                    take: takeFraction(11796),
                    reportedStake: BigRational(numerator: 1000, denominator: 1),
                    status: nil
                )
            ],
            listStamp: SubtensorBackendStamp(asOf: olderAsOf, freshness: .stale),
            isPartial: false,
            isEnrichmentTruncated: false,
            chainBlock: head
        )

        XCTAssertEqual(directory, expected)
        verify(apiFactory, never()).createAlphaYieldWrapper(netuid: any(), page: any())
        verify(apiFactory, never()).createRootYieldWrapper(page: any())
    }

    func testDirectoryEnrichesEveryRowWhenTheMetagraphComponentIsUnavailable() throws {
        let apiFactory = MockBittensorApiOperationFactoryProtocol()
        let chainFactory = MockSubtensorValidatorChainOperationFactoryProtocol()

        var world = ChainWorld(head: head)
        world.seat(hotkeyA, netuid: 64, uid: 5, blocksSinceUpdate: 100)
        world.seat(hotkeyB, netuid: 64, uid: 9, blocksSinceUpdate: 10)

        try stubValidators(apiFactory, result: makeCollection(
            rows: [
                row(hotkeyA, identity: "Aster Stake", stake: "Aster", metagraphUid: nil),
                row(hotkeyB, identity: nil, stake: "BlueHarbor", metagraphUid: nil)
            ],
            completeness: .partial,
            stakes: available(newerAsOf, .fresh),
            metagraph: .unavailable(.temporarilyUnavailable),
            identities: available(olderAsOf, .fresh)
        ))

        stubChain(chainFactory, world: world)

        let service = makeService(apiFactory: apiFactory, chainFactory: chainFactory)

        let directory = try run(service.createDirectoryWrapper(for: subnet))

        XCTAssertTrue(directory.isPartial)
        XCTAssertEqual(directory.listStamp, SubtensorBackendStamp(asOf: olderAsOf, freshness: .fresh))
        XCTAssertEqual(directory.items.map(\.status?.uid), [5, 9])
        XCTAssertEqual(directory.items.map(\.take), [takeFraction(11796), takeFraction(11796)])
    }

    func testDirectoryServedFromAnExpiredCacheHasAStaleListStamp() throws {
        let apiFactory = MockBittensorApiOperationFactoryProtocol()
        let chainFactory = MockSubtensorValidatorChainOperationFactoryProtocol()

        var world = ChainWorld(head: head)
        world.seat(hotkeyA, netuid: 64, uid: 5, blocksSinceUpdate: 100)

        try stubValidators(apiFactory, result: makeCollection(
            rows: [row(hotkeyA, identity: "Aster Stake", stake: nil)],
            stakes: available(olderAsOf, .fresh),
            metagraph: available(newerAsOf, .fresh),
            identities: available(newerAsOf, .fresh),
            isFromExpiredCache: true
        ))

        stubChain(chainFactory, world: world)

        let service = makeService(apiFactory: apiFactory, chainFactory: chainFactory)

        let directory = try run(service.createDirectoryWrapper(for: subnet))

        XCTAssertEqual(directory.listStamp, SubtensorBackendStamp(asOf: olderAsOf, freshness: .stale))
    }

    func testDirectoryEnrichesOnlyTheFirst512Rows() throws {
        let apiFactory = MockBittensorApiOperationFactoryProtocol()
        let chainFactory = MockSubtensorValidatorChainOperationFactoryProtocol()

        let hotkeys = (0 ..< 600).map { index in
            Data([UInt8(index >> 8), UInt8(index & 0xFF)] + [UInt8](repeating: 0x5A, count: 30))
        }

        let world = ChainWorld(head: head)

        try stubValidators(apiFactory, result: makeCollection(
            rows: hotkeys.map { try row($0, identity: nil, stake: nil) },
            stakes: available(olderAsOf, .fresh),
            metagraph: available(olderAsOf, .fresh),
            identities: available(olderAsOf, .fresh)
        ))

        stubChain(chainFactory, world: world)

        let service = makeService(apiFactory: apiFactory, chainFactory: chainFactory)

        let directory = try run(service.createDirectoryWrapper(for: subnet))

        let captor = ArgumentCaptor<SubtensorValidatorChainQuery>()
        verify(chainFactory).createChainSnapshotWrapper(for: captor.capture())

        let expectedPairs = hotkeys.prefix(512).map { pair($0, 64) }

        XCTAssertEqual(captor.value, SubtensorValidatorChainQuery(pairs: expectedPairs, includesHotkeyAlpha: true))
        XCTAssertTrue(directory.isEnrichmentTruncated)
        XCTAssertEqual(directory.items.count, 600)
        XCTAssertNotNil(directory.items[511].take)
        XCTAssertNil(directory.items[512].take)
    }

    func testRootDirectoryListsOnlyMetagraphSeatsWithTheirUidAndTake() throws {
        let apiFactory = MockBittensorApiOperationFactoryProtocol()
        let chainFactory = MockSubtensorValidatorChainOperationFactoryProtocol()

        var world = ChainWorld(head: head)
        world.seat(hotkeyA, netuid: 0, uid: 3)
        world.takes[hotkeyA] = 0

        try stubValidators(apiFactory, result: makeCollection(
            netuid: 0,
            rows: [
                row(hotkeyA, identity: "Aster Stake", stake: nil),
                row(hotkeyB, identity: "BlueHarbor", stake: nil, metagraphUid: nil)
            ],
            stakes: available(olderAsOf, .fresh),
            metagraph: available(olderAsOf, .fresh),
            identities: available(olderAsOf, .fresh)
        ))

        stubChain(chainFactory, world: world)

        let service = makeService(apiFactory: apiFactory, chainFactory: chainFactory)

        let directory = try run(service.createDirectoryWrapper(for: root))

        let expectedRootItem = SubtensorValidatorDirectoryItem(
            hotkey: hotkeyA,
            netuid: 0,
            name: "Aster Stake",
            take: 0,
            reportedStake: BigRational(numerator: 1000, denominator: 1),
            status: SubtensorValidatorChainStatus(uid: 3, hasPermit: nil, blocksSinceUpdate: nil, isActive: nil)
        )

        XCTAssertEqual(directory.items.first, expectedRootItem)
        XCTAssertEqual(directory.items.count, 1)

        let query = ArgumentCaptor<SubtensorValidatorChainQuery>()
        verify(chainFactory).createChainSnapshotWrapper(for: query.capture())
        XCTAssertEqual(query.value?.pairs, [pair(hotkeyA, 0)])
    }

    func testRootDirectoryFailsWhenBackendMetagraphIsUnavailable() throws {
        let apiFactory = MockBittensorApiOperationFactoryProtocol()
        let chainFactory = MockSubtensorValidatorChainOperationFactoryProtocol()

        try stubValidators(apiFactory, result: makeCollection(
            netuid: 0,
            rows: [row(hotkeyA, identity: "Aster Stake", stake: "100", metagraphUid: nil)],
            stakes: available(olderAsOf, .fresh),
            metagraph: .unavailable(.temporarilyUnavailable),
            identities: available(olderAsOf, .fresh)
        ))

        let service = makeService(apiFactory: apiFactory, chainFactory: chainFactory)

        XCTAssertThrowsError(try run(service.createDirectoryWrapper(for: root)))
        verify(chainFactory, never()).createChainSnapshotWrapper(for: any())
    }

    func testDirectoryFailsWhenTheBackendValidatorsCallFails() {
        let apiFactory = MockBittensorApiOperationFactoryProtocol()
        let chainFactory = MockSubtensorValidatorChainOperationFactoryProtocol()

        stub(apiFactory) { stub in
            when(stub.createValidatorsWrapper(netuid: any())).then { _ in
                CompoundOperationWrapper.createWithError(BittensorApiError.upstreamUnavailable(requestId: "request-1"))
            }
        }

        stubChain(chainFactory, world: ChainWorld(head: head))

        let service = makeService(apiFactory: apiFactory, chainFactory: chainFactory)

        XCTAssertThrowsError(try run(service.createDirectoryWrapper(for: subnet))) { error in
            guard case let BittensorApiError.upstreamUnavailable(requestId) = error else {
                return XCTFail("Unexpected error \(error)")
            }

            XCTAssertEqual(requestId, "request-1")
        }

        verify(chainFactory, never()).createChainSnapshotWrapper(for: any())
    }

    func testDetailReusesTheCachedItemOnlyForTheSameSubnetRegistration() throws {
        let apiFactory = MockBittensorApiOperationFactoryProtocol()
        let chainFactory = MockSubtensorValidatorChainOperationFactoryProtocol()

        var world = ChainWorld(head: head)
        world.seat(hotkeyA, netuid: 64, uid: 5, blocksSinceUpdate: 100)

        let identity = SubtensorValidatorIdentity(
            name: "Aster",
            url: "https://aster.example",
            githubRepo: nil,
            image: nil,
            discord: nil,
            description: nil
        )

        try stubValidators(apiFactory, result: makeCollection(
            rows: [row(hotkeyA, identity: "Aster Stake", stake: nil)],
            stakes: available(olderAsOf, .fresh),
            metagraph: available(olderAsOf, .fresh),
            identities: available(olderAsOf, .fresh)
        ))

        stubChain(chainFactory, world: world, identities: [hotkeyA: identity])

        let service = makeService(apiFactory: apiFactory, chainFactory: chainFactory)

        let directory = try run(service.createDirectoryWrapper(for: subnet))
        let cachedDetail = try run(service.createDetailWrapper(for: hotkeyA, subnet: subnet))

        let reRegisteredSubnet = SubtensorSubnetRef(netuid: 64, registeredAt: 9_000_000)
        let chainDetail = try run(service.createDetailWrapper(for: hotkeyA, subnet: reRegisteredSubnet))

        XCTAssertEqual(cachedDetail, SubtensorValidatorDetail(item: directory.items[0], identity: identity))
        XCTAssertNil(chainDetail.item.name)
        XCTAssertEqual(chainDetail.item.status?.uid, 5)
        verify(chainFactory, times(2)).createChainSnapshotWrapper(for: any())
    }

    private func makeService(
        apiFactory: MockBittensorApiOperationFactoryProtocol,
        chainFactory: MockSubtensorValidatorChainOperationFactoryProtocol
    ) -> SubtensorValidatorDirectoryService {
        SubtensorValidatorDirectoryService(
            apiOperationFactory: apiFactory,
            chainOperationFactory: chainFactory,
            operationQueue: OperationQueue()
        )
    }

    private func stubValidators(_ apiFactory: MockBittensorApiOperationFactoryProtocol, result: ValidatorsResult) {
        stub(apiFactory) { stub in
            when(stub.createValidatorsWrapper(netuid: any())).then { _ in
                CompoundOperationWrapper.createWithResult(result)
            }
        }
    }

    private func stubChain(
        _ chainFactory: MockSubtensorValidatorChainOperationFactoryProtocol,
        world: ChainWorld,
        identities: [AccountId: SubtensorValidatorIdentity] = [:]
    ) {
        stub(chainFactory) { stub in
            when(stub.createChainSnapshotWrapper(for: any())).then { query in
                CompoundOperationWrapper.createWithResult(world.snapshot(for: query))
            }

            when(stub.createIdentitiesWrapper(for: any())).then { _ in
                CompoundOperationWrapper.createWithResult(identities)
            }
        }
    }

    private func makeCollection(
        netuid: UInt16 = 64,
        rows: [ValidatorRow],
        completeness: BittensorApi.Completeness = .complete,
        stakes: BittensorApi.ComponentMetadata,
        metagraph: BittensorApi.ComponentMetadata,
        identities: BittensorApi.ComponentMetadata,
        isFromExpiredCache: Bool = false
    ) -> ValidatorsResult {
        let items = rows.map { row in
            BittensorApi.Validator(
                netuid: netuid,
                hotkey: row.hotkey,
                stakeSourceName: row.stake,
                identitySourceName: row.identity,
                metagraphBlockNumber: row.metagraphUid.map { _ in 9_139_990 },
                metagraphUid: row.metagraphUid,
                metagraphColdkey: nil,
                reportedMeasurements: BittensorApi.ValidatorMeasurements(
                    validatorStake: "1000",
                    metagraphStake: nil,
                    reportedTaoStake: nil,
                    reportedAlphaStake: nil,
                    reportedNominatedStake: nil,
                    reportedValidatorTrust: nil,
                    reportedTrust: nil,
                    reportedDividend: nil,
                    reportedIncentive: nil,
                    reportedEmission: nil,
                    reportedTaoDividendsPerHotkey: nil,
                    reportedAlphaDividendsPerHotkey: nil
                )
            )
        }

        let collection = BittensorApi.ValidatorCollection(
            items: items,
            meta: BittensorApi.ValidatorCollection.Meta(
                completeness: completeness,
                components: BittensorApi.ValidatorCollection.Components(
                    validatorStakes: stakes,
                    validatorMetagraph: metagraph,
                    validatorIdentities: identities
                )
            )
        )

        return BittensorApiResult(
            value: collection,
            requestId: "request-1",
            receivedAt: 0,
            isFromExpiredCache: isFromExpiredCache
        )
    }

    private func row(
        _ hotkey: AccountId,
        identity: String?,
        stake: String?,
        metagraphUid: UInt16? = 1
    ) throws -> ValidatorRow {
        ValidatorRow(
            hotkey: try hotkey.toAddress(using: .substrate(SubstrateConstants.genericAddressPrefix)),
            identity: identity,
            stake: stake,
            metagraphUid: metagraphUid
        )
    }

    private func available(_ asOf: Date, _ freshness: BittensorApi.Freshness) -> BittensorApi.ComponentMetadata {
        .available(
            BittensorApi.AvailableComponent(
                asOf: asOf,
                freshness: freshness,
                valueQuality: .reported,
                sourceClass: .primary
            )
        )
    }

    private func pair(_ hotkey: AccountId, _ netuid: UInt16) -> SubtensorHotkeySubnet {
        SubtensorHotkeySubnet(hotkey: hotkey, netuid: netuid)
    }

    private func takeFraction(_ take: UInt16) -> Decimal {
        Decimal(take) / Decimal(65535)
    }

    private func run<T>(_ wrapper: CompoundOperationWrapper<T>) throws -> T {
        let completed = expectation(description: "wrapper completed")

        wrapper.targetOperation.completionBlock = {
            completed.fulfill()
        }

        OperationQueue().addOperations(wrapper.allOperations, waitUntilFinished: false)

        wait(for: [completed], timeout: 10)

        return try wrapper.targetOperation.extractNoCancellableResultData()
    }
}

private struct ValidatorRow {
    let hotkey: String
    let identity: String?
    let stake: String?
    let metagraphUid: UInt16?
}

private struct ChainWorld {
    let head: BlockNumber
    var uids: [SubtensorHotkeySubnet: UInt16] = [:]
    var permits: [UInt16: [Bool]] = [:]
    var lastUpdates: [UInt16: [UInt64]] = [:]
    var takes: [AccountId: UInt16] = [:]
    var alpha: [SubtensorHotkeySubnet: Balance] = [:]

    init(head: BlockNumber) {
        self.head = head
    }

    mutating func seat(_ hotkey: AccountId, netuid: UInt16, uid: UInt16, blocksSinceUpdate: UInt64 = 0) {
        uids[SubtensorHotkeySubnet(hotkey: hotkey, netuid: netuid)] = uid

        guard netuid != 0 else {
            return
        }

        var netuidPermits = permits[netuid] ?? [Bool](repeating: false, count: 256)
        var netuidLastUpdates = lastUpdates[netuid] ?? [UInt64](repeating: 0, count: 256)

        netuidPermits[Int(uid)] = true
        netuidLastUpdates[Int(uid)] = UInt64(head) - blocksSinceUpdate

        permits[netuid] = netuidPermits
        lastUpdates[netuid] = netuidLastUpdates
    }

    func snapshot(for query: SubtensorValidatorChainQuery) -> SubtensorValidatorChainSnapshot {
        let pairs = Set(query.pairs)
        let subnets = Set(query.pairs.map(\.netuid)).subtracting([0])

        return SubtensorValidatorChainSnapshot(
            blockHash: "0x01",
            blockNumber: head,
            uids: uids.filter { pairs.contains($0.key) },
            permits: subnets.reduce(into: [:]) { $0[$1] = permits[$1] ?? [] },
            lastUpdates: subnets.reduce(into: [:]) { $0[$1] = lastUpdates[$1] ?? [] },
            effectiveActivityCutoffs: subnets.reduce(into: [:]) { $0[$1] = 5000 },
            takes: pairs.reduce(into: [:]) { $0[$1.hotkey] = takes[$1.hotkey] ?? 11796 },
            hotkeyAlpha: query.includesHotkeyAlpha ? pairs.reduce(into: [:]) { $0[$1] = alpha[$1] ?? 0 } : [:]
        )
    }
}
