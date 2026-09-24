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

    func testSuccessfulSwapRevealsOutputAssetForInitiatingWalletAfterSelectionChanges() throws {
        // given

        let initiatingWallet = AccountGenerator.generateMetaAccount(generatingChainAccounts: 0)
        let newlySelectedWallet = AccountGenerator.generateMetaAccount(generatingChainAccounts: 0)
        let outputAsset = CommissionTestFixtures.chainAsset(1)
        let operationQueue = OperationQueue()
        operationQueue.isSuspended = true
        let walletSettings = SelectedWalletSettings(
            storageFacade: UserDataStorageTestFacade(),
            operationQueue: operationQueue
        )
        walletSettings.internalValue = initiatingWallet

        let writer = RevealRecordingAssetVisibilityWriter(
            expectation: expectation(description: "Reveal swap output")
        )
        let interactor = SwapExecutionInteractor(
            assetsExchangeService: SuccessfulAssetsExchangeServiceStub(),
            chainAssetOut: outputAsset,
            selectedWalletSettings: walletSettings,
            visibilityWriter: writer,
            osMediator: OperatingSystemMediatorStub(),
            operationQueue: operationQueue
        )

        // when

        interactor.submit(using: createSwapFee())
        walletSettings.internalValue = newlySelectedWallet
        operationQueue.isSuspended = false

        // then

        wait(for: [writer.expectation], timeout: Constants.defaultExpectationDuration)
        let application = try XCTUnwrap(writer.applications.last)
        XCTAssertEqual(application.metaId, initiatingWallet.metaId)
        XCTAssertEqual(application.ids, [outputAsset.chainAssetId])

        guard case .userInitiatedReceipt = application.event else {
            return XCTFail("Expected a user-initiated receipt")
        }
    }

    func testSuccessfulSwapDoesNotRevealWhenThereWasNoWalletAtInitiation() {
        // given

        let operationQueue = OperationQueue()
        operationQueue.isSuspended = true
        let walletSettings = SelectedWalletSettings(
            storageFacade: UserDataStorageTestFacade(),
            operationQueue: operationQueue
        )
        let writer = NoCallAssetVisibilityWriter()
        let output = SwapExecutionOutputSpy(
            expectation: expectation(description: "Finish swap execution")
        )
        let interactor = SwapExecutionInteractor(
            assetsExchangeService: SuccessfulAssetsExchangeServiceStub(),
            chainAssetOut: CommissionTestFixtures.chainAsset(1),
            selectedWalletSettings: walletSettings,
            visibilityWriter: writer,
            osMediator: OperatingSystemMediatorStub(),
            operationQueue: operationQueue
        )
        interactor.presenter = output

        // when

        interactor.submit(using: createSwapFee())
        walletSettings.internalValue = AccountGenerator.generateMetaAccount(generatingChainAccounts: 0)
        operationQueue.isSuspended = false

        // then

        wait(for: [output.expectation], timeout: Constants.defaultExpectationDuration)
        XCTAssertEqual(writer.callCount, 0)
        XCTAssertNil(output.error)
    }

    func testSavingTokenRevealsItForInitiatingWalletAfterSelectionChanges() throws {
        // given

        let initiatingWallet = AccountGenerator.generateMetaAccount(generatingChainAccounts: 0)
        let newlySelectedWallet = AccountGenerator.generateMetaAccount(generatingChainAccounts: 0)
        let chain = ChainModelGenerator.generateChain(
            generatingAssets: 1,
            addressPrefix: 0,
            isEthereumBased: true
        )
        let operationQueue = OperationQueue()
        operationQueue.isSuspended = true
        let walletSettings = SelectedWalletSettings(
            storageFacade: UserDataStorageTestFacade(),
            operationQueue: operationQueue
        )
        walletSettings.internalValue = initiatingWallet
        let writer = RevealRecordingAssetVisibilityWriter(
            expectation: expectation(description: "Reveal saved token")
        )
        let output = TokensManageAddOutputSpy(
            expectation: expectation(description: "Finish saving token")
        )
        let interactor = createTokensManageAddInteractor(
            chain: chain,
            walletSettings: walletSettings,
            writer: writer,
            operationQueue: operationQueue
        )
        interactor.presenter = output
        let token = createTokenRequest()
        let assetId = try XCTUnwrap(AssetModel.createAssetId(from: token.contractAddress))

        // when

        interactor.save(newToken: token)
        walletSettings.internalValue = newlySelectedWallet
        operationQueue.isSuspended = false

        // then

        wait(
            for: [writer.expectation, output.expectation],
            timeout: Constants.defaultExpectationDuration
        )
        let application = try XCTUnwrap(writer.applications.last)
        XCTAssertEqual(application.metaId, initiatingWallet.metaId)
        XCTAssertEqual(application.ids, [ChainAssetId(chainId: chain.chainId, assetId: assetId)])
        XCTAssertNil(output.error)

        guard case let .userSet(isVisible) = application.event else {
            return XCTFail("Expected an explicit visibility event")
        }

        XCTAssertTrue(isVisible)
    }

    func testSavingTokenDoesNotRevealWhenThereWasNoWalletAtInitiation() {
        // given

        let chain = ChainModelGenerator.generateChain(
            generatingAssets: 1,
            addressPrefix: 0,
            isEthereumBased: true
        )
        let operationQueue = OperationQueue()
        operationQueue.isSuspended = true
        let walletSettings = SelectedWalletSettings(
            storageFacade: UserDataStorageTestFacade(),
            operationQueue: operationQueue
        )
        let writer = NoCallAssetVisibilityWriter()
        let output = TokensManageAddOutputSpy(
            expectation: expectation(description: "Finish saving token")
        )
        let interactor = createTokensManageAddInteractor(
            chain: chain,
            walletSettings: walletSettings,
            writer: writer,
            operationQueue: operationQueue
        )
        interactor.presenter = output

        // when

        interactor.save(newToken: createTokenRequest())
        walletSettings.internalValue = AccountGenerator.generateMetaAccount(generatingChainAccounts: 0)
        operationQueue.isSuspended = false

        // then

        wait(for: [output.expectation], timeout: Constants.defaultExpectationDuration)
        XCTAssertEqual(writer.callCount, 0)
        XCTAssertNil(output.error)
    }

    func testAddingCustomNetworkRevealsAssetsForInitiatingWalletAfterSelectionChanges() throws {
        // given

        let initiatingWallet = AccountGenerator.generateMetaAccount(generatingChainAccounts: 0)
        let newlySelectedWallet = AccountGenerator.generateMetaAccount(generatingChainAccounts: 0)
        let network = ChainModelGenerator.generateChain(generatingAssets: 1, addressPrefix: 0)
        let operationQueue = OperationQueue()
        operationQueue.isSuspended = true
        let walletSettings = SelectedWalletSettings(
            storageFacade: UserDataStorageTestFacade(),
            operationQueue: operationQueue
        )
        walletSettings.internalValue = initiatingWallet
        let writer = RevealRecordingAssetVisibilityWriter(
            expectation: expectation(description: "Reveal added custom-network assets")
        )
        let output = CustomNetworkOutputSpy(
            expectation: expectation(description: "Finish adding custom network")
        )
        let factory = createCustomNetworkStrategyFactory(
            walletSettings: walletSettings,
            writer: writer,
            operationQueue: operationQueue
        )
        let strategy = factory.createAddNewStrategy()

        // when

        walletSettings.internalValue = newlySelectedWallet
        strategy.handleSetupFinished(for: network, output: output)
        operationQueue.isSuspended = false

        // then

        wait(
            for: [writer.expectation, output.expectation],
            timeout: Constants.defaultExpectationDuration
        )
        let application = try XCTUnwrap(writer.applications.last)
        XCTAssertEqual(application.metaId, initiatingWallet.metaId)
        XCTAssertEqual(application.ids, Set(network.chainAssets().map(\.chainAssetId)))
        XCTAssertNil(output.error)
    }

    func testAddingCustomNetworkDoesNotRevealWhenThereWasNoWalletAtInitiation() {
        // given

        let network = ChainModelGenerator.generateChain(generatingAssets: 1, addressPrefix: 0)
        let operationQueue = OperationQueue()
        operationQueue.isSuspended = true
        let walletSettings = SelectedWalletSettings(
            storageFacade: UserDataStorageTestFacade(),
            operationQueue: operationQueue
        )
        let writer = NoCallAssetVisibilityWriter()
        let output = CustomNetworkOutputSpy(
            expectation: expectation(description: "Finish adding custom network")
        )
        let factory = createCustomNetworkStrategyFactory(
            walletSettings: walletSettings,
            writer: writer,
            operationQueue: operationQueue
        )
        let strategy = factory.createAddNewStrategy()

        // when

        walletSettings.internalValue = AccountGenerator.generateMetaAccount(generatingChainAccounts: 0)
        strategy.handleSetupFinished(for: network, output: output)
        operationQueue.isSuspended = false

        // then

        wait(for: [output.expectation], timeout: Constants.defaultExpectationDuration)
        XCTAssertEqual(writer.callCount, 0)
        XCTAssertNil(output.error)
    }

    func testChangingCustomNetworkChainIdRevealsAssetsForInitiatingWalletAfterSelectionChanges() throws {
        // given

        let initiatingWallet = AccountGenerator.generateMetaAccount(generatingChainAccounts: 0)
        let newlySelectedWallet = AccountGenerator.generateMetaAccount(generatingChainAccounts: 0)
        let networkToEdit = ChainModelGenerator.generateChain(generatingAssets: 1, addressPrefix: 0)
        let editedNetwork = ChainModelGenerator.generateChain(generatingAssets: 1, addressPrefix: 0)
        let selectedNode = try XCTUnwrap(networkToEdit.nodes.first)
        let operationQueue = OperationQueue()
        operationQueue.isSuspended = true
        let walletSettings = SelectedWalletSettings(
            storageFacade: UserDataStorageTestFacade(),
            operationQueue: operationQueue
        )
        walletSettings.internalValue = initiatingWallet
        let writer = RevealRecordingAssetVisibilityWriter(
            expectation: expectation(description: "Reveal chain-ID-changing edit assets")
        )
        let output = CustomNetworkOutputSpy(
            expectation: expectation(description: "Finish editing custom network")
        )
        let factory = createCustomNetworkStrategyFactory(
            walletSettings: walletSettings,
            writer: writer,
            operationQueue: operationQueue
        )
        let strategy = factory.createEditStrategy(
            networkToEdit: networkToEdit,
            selectedNode: selectedNode
        )

        // when

        walletSettings.internalValue = newlySelectedWallet
        strategy.handleSetupFinished(for: editedNetwork, output: output)
        operationQueue.isSuspended = false

        // then

        wait(
            for: [writer.expectation, output.expectation],
            timeout: Constants.defaultExpectationDuration
        )
        let application = try XCTUnwrap(writer.applications.last)
        XCTAssertEqual(application.metaId, initiatingWallet.metaId)
        XCTAssertEqual(application.ids, Set(editedNetwork.chainAssets().map(\.chainAssetId)))
        XCTAssertNil(output.error)
    }

    func testChangingCustomNetworkChainIdDoesNotRevealWhenThereWasNoWalletAtInitiation() throws {
        // given

        let networkToEdit = ChainModelGenerator.generateChain(generatingAssets: 1, addressPrefix: 0)
        let editedNetwork = ChainModelGenerator.generateChain(generatingAssets: 1, addressPrefix: 0)
        let selectedNode = try XCTUnwrap(networkToEdit.nodes.first)
        let operationQueue = OperationQueue()
        operationQueue.isSuspended = true
        let walletSettings = SelectedWalletSettings(
            storageFacade: UserDataStorageTestFacade(),
            operationQueue: operationQueue
        )
        let writer = NoCallAssetVisibilityWriter()
        let output = CustomNetworkOutputSpy(
            expectation: expectation(description: "Finish editing custom network")
        )
        let factory = createCustomNetworkStrategyFactory(
            walletSettings: walletSettings,
            writer: writer,
            operationQueue: operationQueue
        )
        let strategy = factory.createEditStrategy(
            networkToEdit: networkToEdit,
            selectedNode: selectedNode
        )

        // when

        walletSettings.internalValue = AccountGenerator.generateMetaAccount(generatingChainAccounts: 0)
        strategy.handleSetupFinished(for: editedNetwork, output: output)
        operationQueue.isSuspended = false

        // then

        wait(for: [output.expectation], timeout: Constants.defaultExpectationDuration)
        XCTAssertEqual(writer.callCount, 0)
        XCTAssertNil(output.error)
    }

    func testEditingCustomNetworkWithoutChangingChainIdDoesNotRevealItsAssets() throws {
        // given

        let networkToEdit = ChainModelGenerator.generateChain(generatingAssets: 1, addressPrefix: 0)
        let editedNetwork = ChainModelGenerator.generateChain(
            defaultChainId: networkToEdit.chainId,
            generatingAssets: 1,
            addressPrefix: 0
        )
        let selectedNode = try XCTUnwrap(networkToEdit.nodes.first)
        let operationQueue = OperationQueue()
        let writer = NoCallAssetVisibilityWriter()
        let walletSettings = SelectedWalletSettings(
            storageFacade: UserDataStorageTestFacade(),
            operationQueue: operationQueue
        )
        walletSettings.internalValue = AccountGenerator.generateMetaAccount(generatingChainAccounts: 0)
        let factory = createCustomNetworkStrategyFactory(
            walletSettings: walletSettings,
            writer: writer,
            operationQueue: operationQueue
        )
        let output = CustomNetworkOutputSpy(
            expectation: expectation(description: "Finish editing custom network")
        )

        // when

        factory.createEditStrategy(networkToEdit: networkToEdit, selectedNode: selectedNode)
            .handleSetupFinished(for: editedNetwork, output: output)

        // then

        wait(for: [output.expectation], timeout: Constants.defaultExpectationDuration)
        XCTAssertEqual(writer.callCount, 0)
        XCTAssertNil(output.error)
    }
}

private extension AssetVisibilityRevealTests {
    func createTokenRequest() -> EvmTokenAddRequest {
        EvmTokenAddRequest(
            contractAddress: "0x0000000000000000000000000000000000000001",
            name: nil,
            symbol: "TST",
            decimals: 18,
            priceIdUrl: nil
        )
    }

    func createTokensManageAddInteractor(
        chain: ChainModel,
        walletSettings: SelectedWalletSettings,
        writer: AssetVisibilityWriting,
        operationQueue: OperationQueue
    ) -> TokensManageAddInteractor {
        TokensManageAddInteractor(
            chain: chain,
            connection: SuccessfulEvmQueryEngine(),
            queryFactory: EvmQueryContractMessageFactory(),
            priceIdParser: CoingeckoUrlParser(),
            priceOperationFactory: UnusedCoingeckoOperationFactory(),
            chainRepository: SubstrateRepositoryFactory(storageFacade: SubstrateStorageTestFacade())
                .createChainRepository(),
            selectedWalletSettings: walletSettings,
            visibilityWriter: writer,
            operationQueue: operationQueue
        )
    }

    func createSwapFee() -> AssetExchangeFee {
        AssetExchangeFee(
            route: CommissionTestFixtures.createRoute([.hydraSwap], amount: 1),
            operationFees: [],
            intermediateFeesInAssetIn: 0,
            slippage: BigRational(numerator: 0, denominator: 100),
            feeAssetId: CommissionTestFixtures.asset(0),
            commission: nil
        )
    }

    func createCustomNetworkStrategyFactory(
        walletSettings: SelectedWalletSettings,
        writer: AssetVisibilityWriting,
        operationQueue: OperationQueue
    ) -> CustomNetworkSetupFinishStrategyFactory {
        CustomNetworkSetupFinishStrategyFactory(
            chainRegistry: MockChainRegistryProtocol().applyDefault(for: []),
            repository: SubstrateRepositoryFactory(storageFacade: SubstrateStorageTestFacade())
                .createChainRepository(),
            selectedWalletSettings: walletSettings,
            visibilityWriter: writer,
            operationQueue: operationQueue
        )
    }

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

private final class SwapExecutionOutputSpy: SwapExecutionInteractorOutputProtocol {
    let expectation: XCTestExpectation
    private(set) var error: Error?

    init(expectation: XCTestExpectation) {
        self.expectation = expectation
    }

    func didStartExecution(for _: Int) {}

    func didCompleteFullExecution(received _: Balance) {
        expectation.fulfill()
    }

    func didFailExecution(with error: Error) {
        self.error = error
        expectation.fulfill()
    }
}

private final class TokensManageAddOutputSpy: TokensManageAddInteractorOutputProtocol {
    let expectation: XCTestExpectation
    private(set) var error: TokensManageAddInteractorError?

    init(expectation: XCTestExpectation) {
        self.expectation = expectation
    }

    func didReceiveDetails(_: EvmContractMetadata, for _: AccountAddress) {}

    func didSaveEvmToken(_: EvmTokenAddResult) {
        expectation.fulfill()
    }

    func didReceiveError(_ error: TokensManageAddInteractorError) {
        self.error = error
        expectation.fulfill()
    }
}

private final class SuccessfulEvmQueryEngine: TestJSONRPCEngine {
    override func callMethod<P: Encodable, T: Decodable>(
        _: String,
        params _: P?,
        options _: JSONRPCOptions,
        completion: ((Result<T, Error>) -> Void)?
    ) throws -> UInt16 {
        let value = "0x" + String(repeating: "0", count: 63) + "1"

        guard let response = JSON.stringValue(value) as? T else {
            DispatchQueue.global().async {
                completion?(.failure(CommonError.dataCorruption))
            }
            return 0
        }

        DispatchQueue.global().async {
            completion?(.success(response))
        }

        return 0
    }
}

private final class UnusedCoingeckoOperationFactory: CoingeckoOperationFactoryProtocol {
    func fetchPriceOperation(
        for _: [String],
        currency _: Currency,
        returnsZeroIfUnsupported _: Bool
    ) -> BaseOperation<[PriceData]> {
        fatalError("Unused")
    }

    func fetchPriceHistory(
        for _: String,
        currency _: Currency,
        period _: PriceHistoryPeriod
    ) -> BaseOperation<PriceHistory> {
        fatalError("Unused")
    }
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
