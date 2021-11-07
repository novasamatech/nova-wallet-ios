import XCTest
@testable import fearless
import RobinHood

class EthereumBaseIntegrationTests: XCTestCase {
    func testSubsribeBalance() throws {
        // given

        let accountId = try Data(hexString: "0x2e042c2F97f0952E6fa3D68CD6D65F7201c2de84")
        let chainId = "91bc6e169807aaa54802737e1c504b2577d4fafedd5a02c10293b1cd60e39527"

        let logger = Logger.shared
        let chainStorageFacade = SubstrateStorageTestFacade()
        let chainRegistry = ChainRegistryFacade.setupForIntegrationTest(with: chainStorageFacade)
        let repository = SubstrateRepositoryFactory(storageFacade: chainStorageFacade)
            .createChainStorageItemRepository()
        let operationManager = OperationManager()

        let walletService = WalletRemoteSubscriptionService(
            chainRegistry: chainRegistry,
            repository: repository,
            operationManager: operationManager,
            logger: Logger.shared
        )

        guard let subscriptionId = walletService.attachToAccountInfo(
            of: accountId,
            chainId: chainId,
            chainFormat: .ethereum,
            queue: nil,
            closure: nil,
            subscriptionHandlingFactory: nil
        ) else {
            XCTFail("Can't subscribe to remote storage")
            return
        }

        let walletLocalSubscriptionFactory = WalletLocalSubscriptionFactory(
            chainRegistry: chainRegistry,
            storageFacade: chainStorageFacade,
            operationManager: operationManager,
            logger: Logger.shared
        )

        let accountInfoProvider = try walletLocalSubscriptionFactory.getAccountProvider(
            for: accountId,
            chainId: chainId
        )

        let expectation = XCTestExpectation()

        let updateClosure: ([DataProviderChange<DecodedAccountInfo>]) -> Void = { changes in
            guard let accountInfo = changes.reduceToLastChange()?.item else {
                return
            }

            logger.info("Available: \(accountInfo.data.available)")

            expectation.fulfill()
        }

        let failureClosure: (Error) -> Void = { error in
            XCTFail("Unexpected error \(error)")
        }

        accountInfoProvider.addObserver(self,
                                        deliverOn: .global(),
                                        executing: updateClosure,
                                        failing: failureClosure,
                                        options: DataProviderObserverOptions(
                                            alwaysNotifyOnRefresh: false,
                                            waitsInProgressSyncOnAdd: false
                                        )
        )

        wait(for: [expectation], timeout: 20.0)

        walletService.detachFromAccountInfo(
            for: subscriptionId,
            accountId: accountId,
            chainId: chainId,
            queue: nil,
            closure: nil
        )
    }
}
