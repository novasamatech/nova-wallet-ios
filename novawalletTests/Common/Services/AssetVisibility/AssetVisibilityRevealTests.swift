@testable import novawallet
import Operation_iOS
import SubstrateSdk
import XCTest

final class AssetVisibilityRevealTests: XCTestCase {
    func testSelfTransferRevealsDestinationAssetForRecipientWallet() throws {
        // given

        let storage = UserDataStorageTestFacade()
        let operationQueue = OperationQueue()
        let wallet = AccountGenerator.generateMetaAccount(generatingChainAccounts: 0)
        let chain = ChainModelGenerator.generateChain(generatingAssets: 1, addressPrefix: 0)
        let destination = try XCTUnwrap(chain.chainAssets().first)
        let recipientAccountId = try XCTUnwrap(wallet.fetch(for: chain.accountRequest())?.accountId)
        try save(wallet: wallet, storage: storage, operationQueue: operationQueue)

        let writer = RevealRecordingAssetVisibilityWriter(
            expectation: expectation(description: "Reveal self-transfer destination")
        )
        let revealer = TransferSelfReceiveRevealer(
            accountRepositoryFactory: AccountRepositoryFactory(storageFacade: storage),
            visibilityWriter: writer,
            operationQueue: operationQueue,
            logger: Logger.shared
        )

        // when

        revealer.reveal(destination: destination, recipientAccountId: recipientAccountId)

        // then

        wait(for: [writer.expectation], timeout: Constants.defaultExpectationDuration)
        let application = try XCTUnwrap(writer.applications.last)
        XCTAssertEqual(application.metaId, wallet.metaId)
        XCTAssertEqual(application.ids, [destination.chainAssetId])

        guard case .userInitiatedReceipt = application.event else {
            return XCTFail("Expected a user-initiated receipt")
        }
    }

    func testSuccessfulSwapRevealsOutputAssetForSelectedWallet() throws {
        // given

        let wallet = AccountGenerator.generateMetaAccount(generatingChainAccounts: 0)
        let outputAsset = CommissionTestFixtures.chainAsset(1)
        let walletSettings = SelectedWalletSettings(
            storageFacade: UserDataStorageTestFacade(),
            operationQueue: OperationQueue()
        )
        walletSettings.internalValue = wallet

        let writer = RevealRecordingAssetVisibilityWriter(
            expectation: expectation(description: "Reveal swap output")
        )
        let interactor = SwapExecutionInteractor(
            assetsExchangeService: SuccessfulAssetsExchangeServiceStub(),
            chainAssetOut: outputAsset,
            selectedWalletSettings: walletSettings,
            visibilityWriter: writer,
            osMediator: OperatingSystemMediatorStub(),
            operationQueue: OperationQueue()
        )
        let fee = AssetExchangeFee(
            route: CommissionTestFixtures.createRoute([.hydraSwap], amount: 1),
            operationFees: [],
            intermediateFeesInAssetIn: 0,
            slippage: BigRational(numerator: 0, denominator: 100),
            feeAssetId: CommissionTestFixtures.asset(0),
            commission: nil
        )

        // when

        interactor.submit(using: fee)

        // then

        wait(for: [writer.expectation], timeout: Constants.defaultExpectationDuration)
        let application = try XCTUnwrap(writer.applications.last)
        XCTAssertEqual(application.metaId, wallet.metaId)
        XCTAssertEqual(application.ids, [outputAsset.chainAssetId])

        guard case .userInitiatedReceipt = application.event else {
            return XCTFail("Expected a user-initiated receipt")
        }
    }

    func testModifyingExistingCustomNetworkDoesNotRevealItsAssets() {
        // given

        let network = ChainModelGenerator.generateChain(generatingAssets: 1, addressPrefix: 0)
        let operationQueue = OperationQueue()
        let writer = NoCallAssetVisibilityWriter()
        let walletSettings = SelectedWalletSettings(
            storageFacade: UserDataStorageTestFacade(),
            operationQueue: operationQueue
        )
        walletSettings.internalValue = AccountGenerator.generateMetaAccount(generatingChainAccounts: 0)
        let repository = SubstrateRepositoryFactory(storageFacade: SubstrateStorageTestFacade())
            .createChainRepository()
        let factory = CustomNetworkSetupFinishStrategyFactory(
            chainRegistry: MockChainRegistryProtocol(),
            repository: repository,
            selectedWalletSettings: walletSettings,
            visibilityWriter: writer,
            operationQueue: operationQueue
        )
        let output = CustomNetworkOutputSpy(
            expectation: expectation(description: "Finish modifying custom network")
        )

        // when

        factory.createModifyStrategy(networkToModify: network)
            .handleSetupFinished(for: network, output: output)

        // then

        wait(for: [output.expectation], timeout: Constants.defaultExpectationDuration)
        XCTAssertEqual(writer.callCount, 0)
        XCTAssertNil(output.error)
    }
}

private extension AssetVisibilityRevealTests {
    func save(
        wallet: MetaAccountModel,
        storage: StorageFacadeProtocol,
        operationQueue: OperationQueue
    ) throws {
        let repository = AccountRepositoryFactory(storageFacade: storage)
            .createManagedMetaAccountRepository(for: nil, sortDescriptors: [])
        let managedWallet = ManagedMetaAccountModel(info: wallet, isSelected: true, order: 0)
        let operation = repository.saveOperation({ [managedWallet] }, { [] })

        operationQueue.addOperations([operation], waitUntilFinished: true)
        try operation.extractNoCancellableResultData()
    }
}

private final class RevealRecordingAssetVisibilityWriter: AssetVisibilityWriting {
    struct Application {
        let event: AssetVisibilityEvent
        let metaId: MetaAccountModel.Id
        let ids: Set<ChainAssetId>
    }

    let expectation: XCTestExpectation
    private(set) var applications: [Application] = []

    init(expectation: XCTestExpectation) {
        self.expectation = expectation
    }

    func apply(
        event: AssetVisibilityEvent,
        metaId: MetaAccountModel.Id,
        ids: Set<ChainAssetId>,
        runningCallbackIn _: DispatchQueue?,
        completion: ((Result<Void, Error>) -> Void)?
    ) {
        applications.append(Application(event: event, metaId: metaId, ids: ids))
        expectation.fulfill()
        completion?(.success(()))
    }
}

private final class SuccessfulAssetsExchangeServiceStub: AssetsExchangeServiceProtocol {
    func setup() {}
    func throttle() {}
    func subscribeUpdates(for _: AnyObject, notifyingIn _: DispatchQueue, closure _: @escaping () -> Void) {}
    func unsubscribeUpdates(for _: AnyObject) {}

    func fetchAssetsInWrapper(given _: ChainAssetId?) -> CompoundOperationWrapper<Set<ChainAssetId>> {
        fatalError("Unused")
    }

    func fetchAssetsOutWrapper(given _: ChainAssetId?) -> CompoundOperationWrapper<Set<ChainAssetId>> {
        fatalError("Unused")
    }

    func fetchQuoteWrapper(for _: AssetConversion.QuoteArgs) -> CompoundOperationWrapper<AssetExchangeQuote> {
        fatalError("Unused")
    }

    func estimateFee(for _: AssetExchangeFeeArgs) -> CompoundOperationWrapper<AssetExchangeFee> {
        fatalError("Unused")
    }

    func canPayFee(in _: ChainAsset) -> CompoundOperationWrapper<Bool> {
        fatalError("Unused")
    }

    func submit(
        using _: AssetExchangeFee,
        notifyingIn queue: DispatchQueue,
        operationStartClosure: @escaping (Int) -> Void
    ) -> CompoundOperationWrapper<Balance> {
        queue.async {
            operationStartClosure(0)
        }

        return CompoundOperationWrapper.createWithResult(1)
    }

    func submitSingleOperationWrapper(
        using _: AssetExchangeFee
    ) -> CompoundOperationWrapper<ExtrinsicSubmittedModel> {
        fatalError("Unused")
    }

    func subscribeRequoteService(
        for _: AnyObject,
        ignoreIfAlreadyAdded _: Bool,
        notifyingIn _: DispatchQueue,
        closure _: @escaping () -> Void
    ) {}

    func throttleRequoteService() {}
}

private final class OperatingSystemMediatorStub: OperatingSystemMediating {
    func disableScreenSleep() {}
    func enableScreenSleep() {}
}

private final class NoCallAssetVisibilityWriter: AssetVisibilityWriting {
    private(set) var callCount = 0

    func apply(
        event _: AssetVisibilityEvent,
        metaId _: MetaAccountModel.Id,
        ids _: Set<ChainAssetId>,
        runningCallbackIn _: DispatchQueue?,
        completion _: ((Result<Void, Error>) -> Void)?
    ) {
        callCount += 1
    }
}

private final class CustomNetworkOutputSpy: CustomNetworkBaseInteractorOutputProtocol {
    let expectation: XCTestExpectation
    private(set) var error: CustomNetworkBaseInteractorError?

    init(expectation: XCTestExpectation) {
        self.expectation = expectation
    }

    func didFinishWorkWithNetwork() {
        expectation.fulfill()
    }

    func didReceive(_ error: CustomNetworkBaseInteractorError) {
        self.error = error
        expectation.fulfill()
    }

    func didReceive(knownChain _: ChainModel, selectedNode _: ChainNodeModel) {}
    func didReceive(chain _: ChainModel, selectedNode _: ChainNodeModel) {}
}
