import XCTest
import Cuckoo
import Operation_iOS
@testable import novawallet

final class GiftsSyncServiceTests: XCTestCase {
    private var storageFacade: StorageFacadeProtocol!
    private var service: GiftsSyncService!
    private var mockStatusTracker: MockGiftsStatusTrackerProtocol!
    private var mockGiftsLocalSubscriptionFactory: MockGiftsLocalSubscriptionFactoryProtocol!
    private var giftRepository: AnyDataProviderRepository<GiftModel>!

    private let operationQueue = OperationQueue()

    override func setUp() {
        super.setUp()

        storageFacade = UserDataStorageTestFacade()
        mockStatusTracker = MockGiftsStatusTrackerProtocol()
        mockGiftsLocalSubscriptionFactory = MockGiftsLocalSubscriptionFactoryProtocol()

        let coreDataRepository = InMemoryDataProviderRepository<GiftModel>()
        giftRepository = AnyDataProviderRepository(coreDataRepository)

        setupDefaultStubs()

        service = GiftsSyncService(
            giftsLocalSubscriptionFactory: mockGiftsLocalSubscriptionFactory,
            giftRepository: giftRepository,
            statusTracker: mockStatusTracker,
            operationQueue: operationQueue,
            logger: Logger.shared
        )
    }
}

// MARK: - Tests

extension GiftsSyncServiceTests {
    // MARK: - Setup Tests

    func testSetup_SetsStatusTrackerDelegate() {
        // given
        var capturedDelegate: GiftsStatusTrackerDelegate?

        stub(mockStatusTracker) { stub in
            when(stub.delegate.set(any())).then { delegate in
                capturedDelegate = delegate
            }
            when(stub.delegate.get).thenReturn(nil)
        }

        // when
        service.setup()

        // then
        XCTAssertTrue(capturedDelegate === service)
    }

    func testSetup_SubscribesToGifts() {
        // when
        service.setup()

        // then
        verify(mockGiftsLocalSubscriptionFactory).getAllGiftsProvider(for: any())
    }

    func testSetup_CalledTwice_DoesNotDuplicateSubscription() {
        // when
        service.setup()
        service.setup()

        // then
        verify(mockGiftsLocalSubscriptionFactory, times(1)).getAllGiftsProvider(for: any())
    }

    // MARK: - Gift Changes Tests

    func testGiftChanges_PendingGift_StartsSyncing() {
        // given
        let gift = createTestGift(status: .pending)

        service.setup()

        // when
        service.handleAllGifts(result: .success([.insert(newItem: gift)]))

        // then
        verify(mockStatusTracker).startTracking(for: equal(to: gift))
    }

    func testGiftChanges_ClaimedGift_StopsSyncing() {
        // given
        let gift = createTestGift(status: .claimed)

        service.setup()

        // when
        service.handleAllGifts(result: .success([.insert(newItem: gift)]))

        // then
        verify(mockStatusTracker).stopTracking(for: equal(to: gift.giftAccountId))
    }

    func testGiftChanges_ReclaimedGift_StopsSyncing() {
        // given
        let gift = createTestGift(status: .reclaimed)

        service.setup()

        // when
        service.handleAllGifts(result: .success([.insert(newItem: gift)]))

        // then
        verify(mockStatusTracker).stopTracking(for: equal(to: gift.giftAccountId))
    }

    func testGiftChanges_MultiplePendingGifts_StartsAllSyncing() {
        // given
        let gift1 = createTestGift(accountId: Data(repeating: 1, count: 32), status: .pending)
        let gift2 = createTestGift(accountId: Data(repeating: 2, count: 32), status: .pending)

        service.setup()

        // when
        service.handleAllGifts(result: .success([
            .insert(newItem: gift1),
            .insert(newItem: gift2)
        ]))

        // then
        verify(mockStatusTracker).startTracking(for: equal(to: gift1))
        verify(mockStatusTracker).startTracking(for: equal(to: gift2))
    }

    func testGiftChanges_MixedStatuses_HandlesCorrectly() {
        // given
        let pendingGift = createTestGift(accountId: Data(repeating: 1, count: 32), status: .pending)
        let claimedGift = createTestGift(accountId: Data(repeating: 2, count: 32), status: .claimed)
        let reclaimedGift = createTestGift(accountId: Data(repeating: 3, count: 32), status: .reclaimed)

        service.setup()

        // when
        service.handleAllGifts(result: .success([
            .insert(newItem: pendingGift),
            .insert(newItem: claimedGift),
            .insert(newItem: reclaimedGift)
        ]))

        // then
        verify(mockStatusTracker).startTracking(for: equal(to: pendingGift))
        verify(mockStatusTracker).stopTracking(for: equal(to: claimedGift.giftAccountId))
        verify(mockStatusTracker).stopTracking(for: equal(to: reclaimedGift.giftAccountId))
    }

    func testGiftChanges_UpdatedGift_HandlesCorrectly() {
        // given
        let gift = createTestGift(status: .pending)

        service.setup()

        // when
        service.handleAllGifts(result: .success([.update(newItem: gift)]))

        // then
        verify(mockStatusTracker).startTracking(for: equal(to: gift))
    }

    // MARK: - StatusTracker Delegate Tests

    func testStatusTrackerDelegate_StatusDetermined_SavesGiftWithNewStatus() {
        // given
        let gift = createTestGift(status: .pending)
        let giftAccountId = gift.giftAccountId

        service.setup()
        service.handleAllGifts(result: .success([.insert(newItem: gift)]))

        // when
        service.giftsTracker(mockStatusTracker, didReceive: .claimed, for: giftAccountId)

        // then - wait for save operation to complete, then verify
        operationQueue.waitUntilAllOperationsAreFinished()

        let fetchOperation = giftRepository.fetchOperation(by: { gift.identifier }, options: .init())

        operationQueue.addOperations([fetchOperation], waitUntilFinished: true)

        let savedGift = try? fetchOperation.extractNoCancellableResultData()

        XCTAssertNotNil(savedGift)
        XCTAssertEqual(savedGift?.status, .claimed)
        XCTAssertEqual(savedGift?.giftAccountId, giftAccountId)
    }

    func testStatusTrackerDelegate_StatusDetermined_DoesNotUpdateReclaimedGift() {
        // given
        let gift = createTestGift(status: .reclaimed)
        let giftAccountId = gift.giftAccountId

        service.setup()
        service.handleAllGifts(result: .success([.insert(newItem: gift)]))

        // Track initial operation count
        let initialOperationCount = operationQueue.operationCount

        // when
        service.giftsTracker(mockStatusTracker, didReceive: .claimed, for: giftAccountId)

        // then - no new operations should be added
        XCTAssertEqual(operationQueue.operationCount, initialOperationCount)
    }

    func testStatusTrackerDelegate_StatusDetermined_DoesNotUpdateWhenStatusSame() {
        // given
        let gift = createTestGift(status: .pending)
        let giftAccountId = gift.giftAccountId

        service.setup()
        service.handleAllGifts(result: .success([.insert(newItem: gift)]))

        let initialOperationCount = operationQueue.operationCount

        // when
        service.giftsTracker(mockStatusTracker, didReceive: .pending, for: giftAccountId)

        // then - no save operation triggered
        XCTAssertEqual(operationQueue.operationCount, initialOperationCount)
    }

    func testStatusTrackerDelegate_StatusDetermined_UnknownGift_DoesNothing() {
        // given
        let unknownAccountId = Data(repeating: 99, count: 32)

        service.setup()

        let initialOperationCount = operationQueue.operationCount

        // when
        service.giftsTracker(mockStatusTracker, didReceive: .claimed, for: unknownAccountId)

        // then - no save operation triggered
        XCTAssertEqual(operationQueue.operationCount, initialOperationCount)
    }

    // MARK: - Error Handling Tests

    func testGiftChanges_Error_DoesNotCrash() {
        // given
        service.setup()

        // when
        service.handleAllGifts(result: .failure(NSError(domain: "test", code: 1)))

        // then - should not crash
        verify(mockStatusTracker, never()).startTracking(for: any())
        verify(mockStatusTracker, never()).stopTracking(for: any())
    }
}

// MARK: - Helpers

private extension GiftsSyncServiceTests {
    func setupDefaultStubs() {
        stub(mockStatusTracker) { stub in
            when(stub.delegate.set(any())).thenDoNothing()
            when(stub.delegate.get).thenReturn(nil)
            when(stub.startTracking(for: any())).thenDoNothing()
            when(stub.stopTracking(for: any())).thenDoNothing()
            when(stub.stopTracking()).thenDoNothing()
        }

        stub(mockGiftsLocalSubscriptionFactory) { stub in
            when(stub.getAllGiftsProvider(for: any())).thenReturn(
                createProvider(from: giftRepository)
            )
        }
    }

    func createTestGift(
        accountId: AccountId = Data(repeating: 0, count: 32),
        status: GiftModel.Status
    ) -> GiftModel {
        let chainAssetId = ChainModelGenerator.generateChain(
            generatingAssets: 1,
            addressPrefix: 42
        ).chainAssets().first!.chainAssetId

        return GiftModel(
            amount: 1000,
            chainAssetId: chainAssetId,
            status: status,
            giftAccountId: accountId,
            creationDate: Date(),
            senderMetaId: "test-meta-id"
        )
    }

    func createProvider(from repository: AnyDataProviderRepository<GiftModel>) -> StreamableProvider<GiftModel> {
        StreamableProvider(
            source: AnyStreamableSource(EmptyStreamableSource()),
            repository: repository,
            observable: AnyDataProviderRepositoryObservable(DataProviderObservableStub()),
            operationManager: OperationManager(operationQueue: operationQueue)
        )
    }
}
