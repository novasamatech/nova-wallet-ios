import XCTest
import Cuckoo
import BigInt
import Operation_iOS
@testable import novawallet

final class GiftsStatusTrackerTests: XCTestCase {
    private var statusTracker: GiftsStatusTracker!
    private var mockDelegate: MockGiftsStatusTrackerDelegate!
    private var mockChainRegistry: MockChainRegistryProtocol!
    private var mockGeneralLocalSubscriptionFactory: MockGeneralStorageSubscriptionFactoryProtocol!
    private var mockWalletSubscriptionFactory: MockWalletRemoteSubscriptionFactoryProtocol!
    private var chain: ChainModel!

    private let workingQueue = DispatchQueue.main

    override func setUp() {
        super.setUp()

        mockDelegate = MockGiftsStatusTrackerDelegate()
        mockChainRegistry = MockChainRegistryProtocol()
        mockGeneralLocalSubscriptionFactory = MockGeneralStorageSubscriptionFactoryProtocol()
        mockWalletSubscriptionFactory = MockWalletRemoteSubscriptionFactoryProtocol()

        statusTracker = GiftsStatusTracker(
            chainRegistry: mockChainRegistry,
            generalLocalSubscriptionFactory: mockGeneralLocalSubscriptionFactory,
            walletSubscriptionFactory: mockWalletSubscriptionFactory,
            workingQueue: workingQueue,
            logger: Logger.shared
        )

        statusTracker.delegate = mockDelegate

        chain = createTestChain()

        setupDefaultStubs()
    }
}

// MARK: - Tests

extension GiftsStatusTrackerTests {
    // MARK: - Start Syncing Tests

    func testStartSyncing_AddsAccountIdToSyncingSet_AndNotifiesDelegate() {
        // given
        let gift = createTestGift()
        let expectedAccountId = gift.giftAccountId

        let syncingExpectation = expectation(description: "Delegate notified about syncing account ids")

        stub(mockDelegate) { stub in
            when(stub.giftsTracker(any(), didUpdateTrackingAccountIds: any())).then { _, accountIds in
                XCTAssertTrue(accountIds.contains(expectedAccountId))
                syncingExpectation.fulfill()
            }
        }

        // when
        statusTracker.startTracking(for: gift)

        // then
        wait(for: [syncingExpectation], timeout: 1.0)
        verify(mockDelegate).giftsTracker(any(), didUpdateTrackingAccountIds: any())
    }

    func testStartSyncing_DoesNotDuplicateNotification_WhenCalledTwiceForSameGift() {
        // given
        let gift = createTestGift()
        var notificationCount = 0

        stub(mockDelegate) { stub in
            when(stub.giftsTracker(any(), didUpdateTrackingAccountIds: any())).then { _, _ in
                notificationCount += 1
            }
        }

        // when
        statusTracker.startTracking(for: gift)
        statusTracker.startTracking(for: gift)

        // then
        XCTAssertEqual(notificationCount, 1)
    }

    func testStartSyncing_NotifiesForEachNewGift() {
        // given
        let gift1 = createTestGift(accountId: Data(repeating: 1, count: 32))
        let gift2 = createTestGift(accountId: Data(repeating: 2, count: 32))
        var receivedAccountIds: Set<AccountId> = []

        stub(mockDelegate) { stub in
            when(stub.giftsTracker(any(), didUpdateTrackingAccountIds: any())).then { _, accountIds in
                receivedAccountIds = accountIds
            }
        }

        // when
        statusTracker.startTracking(for: gift1)
        statusTracker.startTracking(for: gift2)

        // then
        XCTAssertEqual(receivedAccountIds.count, 2)
        XCTAssertTrue(receivedAccountIds.contains(gift1.giftAccountId))
        XCTAssertTrue(receivedAccountIds.contains(gift2.giftAccountId))
    }

    // MARK: - Stop Syncing Tests

    func testStopSyncing_RemovesAccountIdFromSyncingSet_AndNotifiesDelegate() {
        // given
        let gift = createTestGift()
        let giftAccountId = gift.giftAccountId
        var lastReceivedAccountIds: Set<AccountId> = []

        stub(mockDelegate) { stub in
            when(stub.giftsTracker(any(), didUpdateTrackingAccountIds: any())).then { _, accountIds in
                lastReceivedAccountIds = accountIds
            }
        }

        statusTracker.startTracking(for: gift)
        XCTAssertTrue(lastReceivedAccountIds.contains(giftAccountId))

        // when
        statusTracker.stopTracking(for: giftAccountId)

        // then
        XCTAssertFalse(lastReceivedAccountIds.contains(giftAccountId))
    }

    func testStopSyncing_DoesNotNotify_WhenAccountWasNotSyncing() {
        // given
        let nonExistentAccountId = Data(repeating: 99, count: 32)
        var notificationCount = 0

        stub(mockDelegate) { stub in
            when(stub.giftsTracker(any(), didUpdateTrackingAccountIds: any())).then { _, _ in
                notificationCount += 1
            }
        }

        // when
        statusTracker.stopTracking(for: nonExistentAccountId)

        // then
        XCTAssertEqual(notificationCount, 0)
    }

    func testStopSyncingAll_ClearsAllSyncingAccountIds() {
        // given
        let gift1 = createTestGift(accountId: Data(repeating: 1, count: 32))
        let gift2 = createTestGift(accountId: Data(repeating: 2, count: 32))
        var lastReceivedAccountIds: Set<AccountId> = []

        stub(mockDelegate) { stub in
            when(stub.giftsTracker(any(), didUpdateTrackingAccountIds: any())).then { _, accountIds in
                lastReceivedAccountIds = accountIds
            }
        }

        statusTracker.startTracking(for: gift1)
        statusTracker.startTracking(for: gift2)
        XCTAssertEqual(lastReceivedAccountIds.count, 2)

        // when
        statusTracker.stopTracking()

        // then
        XCTAssertTrue(lastReceivedAccountIds.isEmpty)
    }

    // MARK: - Balance Update Tests

    func testBalanceUpdate_WithAmountTransferable_EmitsPendingStatus() {
        // given
        let gift = createTestGift()
        let giftAccountId = gift.giftAccountId

        var capturedCallback: WalletRemoteSubscriptionClosure?
        let mockSubscription = setupMockSubscription { callback in
            capturedCallback = callback
        }

        stub(mockWalletSubscriptionFactory) { stub in
            when(stub.createSubscription()).thenReturn(mockSubscription)
        }

        let statusExpectation = expectation(description: "Delegate receives pending status")

        stub(mockDelegate) { stub in
            when(stub.giftsTracker(any(), didReceive: any(), for: any())).then { _, status, accountId in
                XCTAssertEqual(status, .pending)
                XCTAssertEqual(accountId, giftAccountId)
                statusExpectation.fulfill()
            }
            when(stub.giftsTracker(any(), didUpdateTrackingAccountIds: any())).thenDoNothing()
        }

        statusTracker.startTracking(for: gift)

        // when
        let balance = createAssetBalance(
            transferable: gift.amount + 1,
            chainAssetId: gift.chainAssetId,
            accountId: giftAccountId
        )
        capturedCallback?(.success(.init(balance: balance, blockHash: nil)))

        // then
        wait(for: [statusExpectation], timeout: 1.0)
    }

    func testBalanceUpdate_WithZeroTransferable_EmitsClaimedStatus() {
        // given
        let gift = createTestGift()
        let giftAccountId = gift.giftAccountId

        var capturedCallback: WalletRemoteSubscriptionClosure?
        let mockSubscription = setupMockSubscription { callback in
            capturedCallback = callback
        }

        stub(mockWalletSubscriptionFactory) { stub in
            when(stub.createSubscription()).thenReturn(mockSubscription)
        }

        let statusExpectation = expectation(description: "Delegate receives claimed status")

        stub(mockDelegate) { stub in
            when(stub.giftsTracker(any(), didReceive: any(), for: any())).then { _, status, accountId in
                XCTAssertEqual(status, .claimed)
                XCTAssertEqual(accountId, giftAccountId)
                statusExpectation.fulfill()
            }
            when(stub.giftsTracker(any(), didUpdateTrackingAccountIds: any())).thenDoNothing()
        }

        statusTracker.startTracking(for: gift)

        // when
        let balance = createAssetBalance(
            transferable: 0,
            chainAssetId: gift.chainAssetId,
            accountId: giftAccountId
        )
        capturedCallback?(.success(.init(balance: balance, blockHash: nil)))

        // then
        wait(for: [statusExpectation], timeout: 1.0)
    }

    func testBalanceUpdate_RemovesFromSyncingSet_WhenStatusDetermined() {
        // given
        let gift = createTestGift()
        let giftAccountId = gift.giftAccountId

        var capturedCallback: WalletRemoteSubscriptionClosure?
        let mockSubscription = setupMockSubscription { callback in
            capturedCallback = callback
        }

        stub(mockWalletSubscriptionFactory) { stub in
            when(stub.createSubscription()).thenReturn(mockSubscription)
        }

        var lastReceivedAccountIds: Set<AccountId> = []

        stub(mockDelegate) { stub in
            when(stub.giftsTracker(any(), didReceive: any(), for: any())).thenDoNothing()
            when(stub.giftsTracker(any(), didUpdateTrackingAccountIds: any())).then { _, accountIds in
                lastReceivedAccountIds = accountIds
            }
        }

        statusTracker.startTracking(for: gift)
        XCTAssertTrue(lastReceivedAccountIds.contains(giftAccountId))

        // when
        let balance = createAssetBalance(
            transferable: gift.amount + 1,
            chainAssetId: gift.chainAssetId,
            accountId: giftAccountId
        )
        capturedCallback?(.success(.init(balance: balance, blockHash: nil)))

        // then
        XCTAssertFalse(lastReceivedAccountIds.contains(giftAccountId))
    }

    // MARK: - Block Counting Tests

    func testNilBalance_StartsBlockCounting() {
        // given
        let gift = createTestGift()

        var capturedCallback: WalletRemoteSubscriptionClosure?
        let mockSubscription = setupMockSubscription { callback in
            capturedCallback = callback
        }

        stub(mockWalletSubscriptionFactory) { stub in
            when(stub.createSubscription()).thenReturn(mockSubscription)
        }

        stub(mockDelegate) { stub in
            when(stub.giftsTracker(any(), didReceive: any(), for: any())).thenDoNothing()
            when(stub.giftsTracker(any(), didUpdateTrackingAccountIds: any())).thenDoNothing()
        }

        statusTracker.startTracking(for: gift)

        // when
        capturedCallback?(.success(.init(balance: nil, blockHash: nil)))

        // then
        verify(mockGeneralLocalSubscriptionFactory).getBlockNumberProvider(for: any())
    }

    func testBlockCounting_EmitsClaimedStatus_After10Blocks() {
        // given
        let gift = createTestGift()
        let chainId = gift.chainAssetId.chainId

        var capturedCallback: WalletRemoteSubscriptionClosure?
        let mockSubscription = setupMockSubscription { callback in
            capturedCallback = callback
        }

        stub(mockWalletSubscriptionFactory) { stub in
            when(stub.createSubscription()).thenReturn(mockSubscription)
        }

        var receivedStatus: GiftModel.Status?
        let statusExpectation = expectation(description: "Delegate receives claimed status after block counting")

        stub(mockDelegate) { stub in
            when(stub.giftsTracker(any(), didReceive: any(), for: any())).then { _, status, _ in
                receivedStatus = status
                statusExpectation.fulfill()
            }
            when(stub.giftsTracker(any(), didUpdateTrackingAccountIds: any())).thenDoNothing()
        }

        statusTracker.startTracking(for: gift)

        // Start block counting with nil balance
        capturedCallback?(.success(.init(balance: nil, blockHash: nil)))

        // when - simulate block number updates
        let startBlock: BlockNumber = 100

        // First block sets the start block
        statusTracker.handleBlockNumber(result: .success(startBlock), chainId: chainId)

        // Simulate 10 more blocks passing
        statusTracker.handleBlockNumber(result: .success(startBlock + 10), chainId: chainId)

        // then
        wait(for: [statusExpectation], timeout: 2.0)
        XCTAssertEqual(receivedStatus, .claimed)
    }

    func testBlockCounting_DoesNotEmitStatus_Before10Blocks() {
        // given
        let gift = createTestGift()
        let chainId = gift.chainAssetId.chainId

        var capturedCallback: WalletRemoteSubscriptionClosure?
        let mockSubscription = setupMockSubscription { callback in
            capturedCallback = callback
        }

        stub(mockWalletSubscriptionFactory) { stub in
            when(stub.createSubscription()).thenReturn(mockSubscription)
        }

        stub(mockDelegate) { stub in
            when(stub.giftsTracker(any(), didReceive: any(), for: any())).thenDoNothing()
            when(stub.giftsTracker(any(), didUpdateTrackingAccountIds: any())).thenDoNothing()
        }

        statusTracker.startTracking(for: gift)
        capturedCallback?(.success(.init(balance: nil, blockHash: nil)))

        let startBlock: BlockNumber = 100
        statusTracker.handleBlockNumber(result: .success(startBlock), chainId: chainId)

        // when - only 9 blocks passed
        statusTracker.handleBlockNumber(result: .success(startBlock + 9), chainId: chainId)

        // then - should not have called didReceive
        verify(mockDelegate, never()).giftsTracker(any(), didReceive: any(), for: any())
    }

    func testBlockCounting_CancelledByNonNilBalance_EmitsPendingStatus() {
        // given
        let gift = createTestGift()
        let giftAccountId = gift.giftAccountId
        let chainId = gift.chainAssetId.chainId

        var capturedCallback: WalletRemoteSubscriptionClosure?
        let mockSubscription = setupMockSubscription { callback in
            capturedCallback = callback
        }

        stub(mockWalletSubscriptionFactory) { stub in
            when(stub.createSubscription()).thenReturn(mockSubscription)
        }

        var receivedStatuses: [GiftModel.Status] = []

        stub(mockDelegate) { stub in
            when(stub.giftsTracker(any(), didReceive: any(), for: any())).then { _, status, _ in
                receivedStatuses.append(status)
            }
            when(stub.giftsTracker(any(), didUpdateTrackingAccountIds: any())).thenDoNothing()
        }

        statusTracker.startTracking(for: gift)

        // Start block counting with nil balance
        capturedCallback?(.success(.init(balance: nil, blockHash: nil)))

        let startBlock: BlockNumber = 100
        statusTracker.handleBlockNumber(result: .success(startBlock), chainId: chainId)

        // when - balance becomes non-nil before 10 blocks
        statusTracker.handleBlockNumber(result: .success(startBlock + 5), chainId: chainId)

        let balance = createAssetBalance(
            transferable: gift.amount + 1,
            chainAssetId: gift.chainAssetId,
            accountId: giftAccountId
        )
        capturedCallback?(.success(.init(balance: balance, blockHash: nil)))

        // then - should receive pending status, not claimed
        XCTAssertEqual(receivedStatuses.count, 1)
        XCTAssertEqual(receivedStatuses.first, .pending)
    }

    func testBlockCounting_IndependentForMultipleGifts() {
        // given
        let gift1 = createTestGift(accountId: Data(repeating: 1, count: 32))
        let gift2 = createTestGift(accountId: Data(repeating: 2, count: 32))
        let chainId = gift1.chainAssetId.chainId

        var capturedCallback1: WalletRemoteSubscriptionClosure?
        var capturedCallback2: WalletRemoteSubscriptionClosure?

        let mockSubscription1 = setupMockSubscription { callback in
            capturedCallback1 = callback
        }
        let mockSubscription2 = setupMockSubscription { callback in
            capturedCallback2 = callback
        }

        var subscriptionIndex = 0
        stub(mockWalletSubscriptionFactory) { stub in
            when(stub.createSubscription()).then { _ -> WalletRemoteSubscriptionProtocol in
                subscriptionIndex += 1
                return subscriptionIndex == 1 ? mockSubscription1 : mockSubscription2
            }
        }

        var receivedStatusesForGift1: [GiftModel.Status] = []
        var receivedStatusesForGift2: [GiftModel.Status] = []

        stub(mockDelegate) { stub in
            when(stub.giftsTracker(any(), didReceive: any(), for: any())).then { _, status, accountId in
                if accountId == gift1.giftAccountId {
                    receivedStatusesForGift1.append(status)
                } else if accountId == gift2.giftAccountId {
                    receivedStatusesForGift2.append(status)
                }
            }
            when(stub.giftsTracker(any(), didUpdateTrackingAccountIds: any())).thenDoNothing()
        }

        statusTracker.startTracking(for: gift1)
        statusTracker.startTracking(for: gift2)

        // Start block counting for both
        capturedCallback1?(.success(.init(balance: nil, blockHash: nil)))
        capturedCallback2?(.success(.init(balance: nil, blockHash: nil)))

        // when
        let startBlock: BlockNumber = 100
        statusTracker.handleBlockNumber(result: .success(startBlock), chainId: chainId)

        // Gift 1 receives balance after 5 blocks
        statusTracker.handleBlockNumber(result: .success(startBlock + 5), chainId: chainId)

        let balance = createAssetBalance(
            transferable: gift1.amount + 1,
            chainAssetId: gift1.chainAssetId,
            accountId: gift1.giftAccountId
        )
        capturedCallback1?(.success(.init(balance: balance, blockHash: nil)))

        // Gift 2 continues to 10 blocks
        statusTracker.handleBlockNumber(result: .success(startBlock + 10), chainId: chainId)

        // then
        XCTAssertEqual(receivedStatusesForGift1, [.pending])
        XCTAssertEqual(receivedStatusesForGift2, [.claimed])
    }

    // MARK: - Chain Not Found Tests

    func testStartSyncing_DoesNothing_WhenChainNotFound() {
        // given
        let gift = createTestGift()

        stub(mockChainRegistry) { stub in
            when(stub.getChain(for: any())).thenReturn(nil)
        }

        stub(mockDelegate) { stub in
            when(stub.giftsTracker(any(), didUpdateTrackingAccountIds: any())).thenDoNothing()
        }

        // when
        statusTracker.startTracking(for: gift)

        // then
        verify(mockDelegate, never()).giftsTracker(any(), didUpdateTrackingAccountIds: any())
    }
}

// MARK: - Helpers

private extension GiftsStatusTrackerTests {
    func setupDefaultStubs() {
        stub(mockChainRegistry) { stub in
            when(stub.getChain(for: any())).thenReturn(chain)
        }

        stub(mockGeneralLocalSubscriptionFactory) { stub in
            when(stub.getBlockNumberProvider(for: any())).thenReturn(
                AnyDataProvider(DataProviderStub<DecodedBlockNumber>(models: []))
            )
        }

        let mockSubscription = setupMockSubscription { _ in }
        stub(mockWalletSubscriptionFactory) { stub in
            when(stub.createSubscription()).thenReturn(mockSubscription)
        }
    }

    func setupMockSubscription(
        capturingCallback: @escaping (WalletRemoteSubscriptionClosure?) -> Void
    ) -> MockWalletRemoteSubscriptionProtocol {
        let mockSubscription = MockWalletRemoteSubscriptionProtocol()

        stub(mockSubscription) { stub in
            when(stub.subscribeBalance(
                for: any(),
                chainAsset: any(),
                callbackQueue: any(),
                callbackClosure: any()
            )).then { _, _, _, callback in
                capturingCallback(callback)
            }
            when(stub.unsubscribe()).thenDoNothing()
        }

        return mockSubscription
    }

    func createTestGift(
        accountId: AccountId = Data(repeating: 0, count: 32)
    ) -> GiftModel {
        let chainAssetId = chain.chainAssets().first!.chainAssetId

        return GiftModel(
            amount: 1000,
            chainAssetId: chainAssetId,
            status: .pending,
            giftAccountId: accountId,
            creationDate: Date(),
            senderMetaId: "test"
        )
    }

    func createTestChain() -> ChainModel {
        ChainModelGenerator.generateChain(
            generatingAssets: 1,
            addressPrefix: 42
        )
    }

    func createAssetBalance(
        transferable: BigUInt,
        chainAssetId: ChainAssetId,
        accountId: AccountId
    ) -> AssetBalance {
        AssetBalance(
            chainAssetId: chainAssetId,
            accountId: accountId,
            freeInPlank: transferable,
            reservedInPlank: 0,
            frozenInPlank: 0,
            edCountMode: .basedOnFree,
            transferrableMode: .regular,
            blocked: false
        )
    }
}
