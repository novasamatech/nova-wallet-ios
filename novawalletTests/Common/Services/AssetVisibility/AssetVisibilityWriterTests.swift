@testable import novawallet
import Operation_iOS
import XCTest

final class AssetVisibilityWriterTests: XCTestCase {
    private let metaId = "test-wallet"
    private let assetId = ChainAssetId(chainId: "test-chain", assetId: 0)

    func testPassivePositiveBalanceDoesNotOverrideHiddenAsset() throws {
        // given

        let context = TestContext()
        try context.save(state: .hidden, metaId: metaId, assetId: assetId)

        // when

        try context.apply(
            event: .passivePositiveBalance(autoAddEnabled: true),
            metaId: metaId,
            assetId: assetId
        )

        // then

        XCTAssertEqual(try context.fetchState(metaId: metaId, assetId: assetId), .hidden)
    }

    func testPassivePositiveBalanceRevealsUndecidedAsset() throws {
        // given

        let context = TestContext()

        // when

        try context.apply(
            event: .passivePositiveBalance(autoAddEnabled: true),
            metaId: metaId,
            assetId: assetId
        )

        // then

        XCTAssertEqual(try context.fetchState(metaId: metaId, assetId: assetId), .visible)
    }

    func testDisabledAutoAddDoesNotRevealUndecidedAsset() throws {
        // given

        let context = TestContext()

        // when

        try context.apply(
            event: .passivePositiveBalance(autoAddEnabled: false),
            metaId: metaId,
            assetId: assetId
        )

        // then

        XCTAssertNil(try context.fetchState(metaId: metaId, assetId: assetId))
    }

    func testUserInitiatedReceiptOverridesHiddenAsset() throws {
        // given

        let context = TestContext()
        try context.save(state: .hidden, metaId: metaId, assetId: assetId)

        // when

        try context.apply(event: .userInitiatedReceipt, metaId: metaId, assetId: assetId)

        // then

        XCTAssertEqual(try context.fetchState(metaId: metaId, assetId: assetId), .visible)
    }

    func testVisibilityWritesAreScopedPerWallet() throws {
        // given

        let context = TestContext()
        let otherMetaId = "other-wallet"
        try context.save(state: .hidden, metaId: metaId, assetId: assetId)

        // when

        try context.apply(event: .userInitiatedReceipt, metaId: otherMetaId, assetId: assetId)

        // then

        XCTAssertEqual(try context.fetchState(metaId: metaId, assetId: assetId), .hidden)
        XCTAssertEqual(try context.fetchState(metaId: otherMetaId, assetId: assetId), .visible)
    }
}

private extension AssetVisibilityWriterTests {
    final class TestContext {
        private let storage = UserDataStorageTestFacade()
        private let writeQueue = OperationQueue()
        private let workQueue = OperationQueue()

        private lazy var writer = AssetVisibilityWriter(
            storageFacade: storage,
            writeQueue: writeQueue,
            workQueue: workQueue,
            logger: Logger.shared
        )

        func apply(
            event: AssetVisibilityEvent,
            metaId: MetaAccountModel.Id,
            assetId: ChainAssetId
        ) throws {
            let completion = XCTestExpectation(description: "Apply asset visibility event")
            var result: Result<Void, Error>?

            writer.apply(
                event: event,
                metaId: metaId,
                ids: [assetId],
                runningCallbackIn: .main
            ) {
                result = $0
                completion.fulfill()
            }

            XCTWaiter().wait(for: [completion], timeout: Constants.defaultExpectationDuration)
            try XCTUnwrap(result).get()
        }

        func save(
            state: AssetVisibilityState,
            metaId: MetaAccountModel.Id,
            assetId: ChainAssetId
        ) throws {
            let row = AssetVisibilityLocal(
                metaId: metaId,
                chainId: assetId.chainId,
                assetId: assetId.assetId,
                state: state
            )
            let operation = repository(for: metaId).saveOperation({ [row] }, { [] })

            workQueue.addOperations([operation], waitUntilFinished: true)
            try operation.extractNoCancellableResultData()
        }

        func fetchState(
            metaId: MetaAccountModel.Id,
            assetId: ChainAssetId
        ) throws -> AssetVisibilityState? {
            let operation = repository(for: metaId).fetchAllOperation(with: RepositoryFetchOptions())

            workQueue.addOperations([operation], waitUntilFinished: true)

            return try operation.extractNoCancellableResultData()
                .first { $0.chainAssetId == assetId }?
                .state
        }

        private func repository(
            for metaId: MetaAccountModel.Id
        ) -> AnyDataProviderRepository<AssetVisibilityLocal> {
            AssetVisibilityRepositoryFactory.createVisibilityRepository(
                for: metaId,
                using: storage
            )
        }
    }
}
