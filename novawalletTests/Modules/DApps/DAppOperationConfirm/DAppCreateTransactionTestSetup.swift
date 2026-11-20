import BigInt
import Cuckoo
import Foundation_iOS
@testable import novawallet
import Operation_iOS
import SubstrateSdk
import XCTest

/// The createTransaction confirmation assembled the way `DAppOperationConfirmViewFactory` assembles it,
/// with the node, the storage and the keys replaced by test doubles.
struct DAppCreateTransactionTestSetup {
    struct Options {
        var walletType: MetaAccountModelType = .secrets
        var signingWrapperFactory: SigningWrapperFactoryProtocol = DummySigningWrapperFactory()

        /// Nil stands for `ExtrinsicGoldenRuntime.makeChain()`
        var chain: ChainModel?

        /// What the node answers to the fee query; it never includes a tip
        var nodeFee = BigUInt(1)

        /// How many fee queries fail before the node starts answering
        var failingFeeQueries = 0

        var metadataHashFactory: MetadataHashOperationFactoryProtocol = DAppMetadataHashFactoryStub(metadataHash: nil)

        /// Replaces the pools of Asset Hub: units of the fee asset taken for a unit of the native token
        var feeAssetRate: BigUInt?
    }

    let view = MockDAppOperationConfirmViewProtocol()
    let wireframe = MockDAppOperationConfirmWireframeProtocol()
    let delegate = MockDAppOperationConfirmDelegate()
    let presenter: DAppOperationConfirmPresenter
    let interactor: DAppCreateTransactionConfirmInteractor
    let request: DAppOperationRequest
    let chain: ChainModel

    init(
        runtime: ExtrinsicGoldenRuntime,
        fixture: DAppTxPayloadFixture,
        options: Options = Options()
    ) throws {
        chain = try options.chain ?? ExtrinsicGoldenRuntime.makeChain()

        let wallet = MetaAccountModel(
            metaId: UUID().uuidString,
            name: "Test",
            substrateAccountId: ExtrinsicGolden.senderId,
            substrateCryptoType: 0,
            substratePublicKey: ExtrinsicGolden.senderId,
            ethereumAddress: nil,
            ethereumPublicKey: nil,
            chainAccounts: [],
            type: options.walletType,
            multisig: nil
        )

        let account = try XCTUnwrap(wallet.fetch(for: chain.accountRequest()))

        request = DAppOperationRequest(
            transportName: DAppTransports.polkadotExtension,
            identifier: UUID().uuidString,
            wallet: wallet,
            accountId: account.accountId,
            dApp: "Test",
            dAppIcon: nil,
            operationData: try fixture.makeRequestJSON()
        )

        let runtimeProvider = Self.makeRuntimeProvider(for: runtime, chain: chain)
        let connection = Self.makeConnection(with: options)
        let operationQueue = OperationQueue()

        let extrinsicFactory = DAppTxPayloadExtrinsicOperationFactory(
            payload: try request.operationData.map(to: PolkadotExtensionTxPayload.self),
            chain: chain,
            runtimeProvider: runtimeProvider,
            connection: connection,
            resolver: DAppTxPayloadExtensionResolver(),
            metadataHashOperationFactory: options.metadataHashFactory,
            senderResolvingFactory: ExtrinsicSenderResolutionFactoryStub(
                resolver: ExtrinsicCurrentSenderResolver(currentAccount: account)
            ),
            nonceOperationFactory: TransactionNonceOperationFactory(),
            eraOperationFactory: PresetEraOperationFactory(
                parameters: ExtrinsicEraParameters(blockNumber: 100, extrinsicEra: ExtrinsicGolden.era)
            ),
            blockHashOperationFactory: DAppBlockHashFactoryStub(),
            signedExtensionFactory: ExtrinsicSignedExtensionFactory(),
            operationQueue: operationQueue
        )

        let feeHost = ExtrinsicFeeEstimatorHost(
            account: account,
            chain: chain,
            connection: connection,
            runtimeProvider: runtimeProvider,
            userStorageFacade: UserDataStorageTestFacade(),
            substrateStorageFacade: SubstrateStorageTestFacade(),
            operationQueue: operationQueue
        )

        let feeOperationFactory = ExtrinsicProxyOperationFactory(
            proxy: extrinsicFactory,
            runtimeRegistry: runtimeProvider,
            engine: connection,
            feeEstimationRegistry: Self.makeFeeEstimationRegistry(host: feeHost, feeAssetRate: options.feeAssetRate),
            operationManager: OperationManager(operationQueue: operationQueue),
            usesStateCallForFee: chain.feeViaRuntimeCall
        )

        interactor = DAppCreateTransactionConfirmInteractor(
            request: request,
            chain: chain,
            account: account,
            extrinsicFactory: extrinsicFactory,
            feeOperationFactory: feeOperationFactory,
            signingWrapperFactory: options.signingWrapperFactory,
            priceProviderFactory: PriceProviderFactoryStub(priceData: nil),
            currencyManager: CurrencyManagerStub(),
            operationQueue: operationQueue
        )

        presenter = DAppOperationConfirmPresenter(
            interactor: interactor,
            wireframe: wireframe,
            delegate: delegate,
            viewModelFactory: DAppOperationGenericConfirmViewModelFactory(chain: .left(chain)),
            balanceViewModelFacade: BalanceViewModelFactoryFacade(
                priceAssetInfoFactory: PriceAssetInfoFactory(currencyManager: CurrencyManagerStub())
            ),
            chain: .left(chain),
            signAnalyticsContext: nil,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view
        interactor.presenter = presenter
    }
}

private extension DAppCreateTransactionTestSetup {
    static func makeRuntimeProvider(
        for runtime: ExtrinsicGoldenRuntime,
        chain: ChainModel
    ) -> MockRuntimeProviderProtocol {
        let runtimeProvider = MockRuntimeProviderProtocol()

        stub(runtimeProvider) { stub in
            stub.fetchCoderFactoryOperation().then {
                BaseOperation.createWithResult(runtime.codingFactory)
            }

            stub.chainId.get.thenReturn(chain.chainId)
        }

        return runtimeProvider
    }

    static func makeConnection(with options: Options) -> MockConnection {
        let connection = MockConnection()
        let feeQueries = DAppFeeQueryCounter(failingQueries: options.failingFeeQueries)

        stub(connection.internalConnection) { stub in
            when(
                stub.callMethod(any(), params: any(), options: any(), completion: any())
            ).then { (_, _: [String]?, _, completion: ((Result<RuntimeDispatchInfo, Error>) -> Void)?) in
                let fee = RuntimeDispatchInfo(fee: String(options.nodeFee), weight: .init(refTime: 32, proofSize: 0))
                let result: Result<RuntimeDispatchInfo, Error> = feeQueries.shouldFailNext()
                    ? .failure(CommonError.undefined)
                    : .success(fee)

                DispatchQueue.global().async {
                    completion?(result)
                }

                return 0
            }
        }

        return connection
    }

    /// The registry of `DAppOperationConfirmViewFactory`. A rate replaces only the source of the quotes,
    /// which the app takes from the node.
    static func makeFeeEstimationRegistry(
        host: ExtrinsicFeeEstimatorHost,
        feeAssetRate: BigUInt?
    ) -> ExtrinsicFeeEstimationRegistring {
        guard let feeAssetRate else {
            return DAppOperationConfirmViewFactory.createTxPayloadFeeEstimationRegistry(host: host)
        }

        let nativeFeeEstimator = DAppOperationConfirmViewFactory.createTxPayloadNativeFeeEstimator(host: host)

        return ExtrinsicFeeEstimationRegistry(
            chain: host.chain,
            estimatingWrapperFactory: ExtrinsicFeeEstimatingWrapperFactory(
                host: host,
                customFeeEstimatorFactory: DAppFixedRateFeeEstimatingFactory(
                    rate: feeAssetRate,
                    nativeFeeEstimator: nativeFeeEstimator,
                    operationQueue: host.operationQueue
                ),
                nativeFeeEstimator: nativeFeeEstimator
            ),
            feeInstallingWrapperFactory: AssetConversionFeeInstallingFactory(host: host)
        )
    }
}

private final class DAppFeeQueryCounter {
    private let lock = NSLock()
    private var remainedFailures: Int

    init(failingQueries: Int) {
        remainedFailures = failingQueries
    }

    func shouldFailNext() -> Bool {
        lock.lock()
        defer { lock.unlock() }

        guard remainedFailures > 0 else {
            return false
        }

        remainedFailures -= 1

        return true
    }
}

/// Converts the fee with the app's own estimator but quotes a fixed rate instead of asking the pools.
private final class DAppFixedRateFeeEstimatingFactory: ExtrinsicCustomFeeEstimatingFactoryProtocol, AssetQuoteFactoryProtocol {
    let rate: BigUInt
    let nativeFeeEstimator: ExtrinsicFeeEstimating
    let operationQueue: OperationQueue

    init(rate: BigUInt, nativeFeeEstimator: ExtrinsicFeeEstimating, operationQueue: OperationQueue) {
        self.rate = rate
        self.nativeFeeEstimator = nativeFeeEstimator
        self.operationQueue = operationQueue
    }

    func createCustomFeeEstimator(for chainAsset: ChainAsset) -> ExtrinsicFeeEstimating? {
        ExtrinsicAssetConversionFeeEstimator(
            chainAsset: chainAsset,
            operationQueue: operationQueue,
            quoteFactory: self,
            feeBufferInPercentage: BigRational.percent(of: 0),
            nativeFeeEstimator: nativeFeeEstimator
        )
    }

    func quote(for args: AssetConversion.QuoteArgs) -> CompoundOperationWrapper<AssetConversion.Quote> {
        .createWithResult(AssetConversion.Quote(args: args, amount: args.amount * rate, context: nil))
    }
}

/// Collects what the interactor reports, for the tests that check the numbers behind the screen.
final class DAppOperationConfirmOutputSpy: DAppOperationConfirmInteractorOutputProtocol {
    let modelExpectation = XCTestExpectation(description: "model")
    let feeExpectation = XCTestExpectation(description: "fee")
    let responseExpectation = XCTestExpectation(description: "response")

    private(set) var modelResults: [Result<DAppOperationConfirmModel, Error>] = []
    private(set) var feeResults: [Result<FeeOutputModel, Error>] = []
    private(set) var responseResults: [Result<DAppOperationResponse, Error>] = []

    init() {
        [modelExpectation, feeExpectation, responseExpectation].forEach { $0.assertForOverFulfill = false }
    }

    func didReceive(modelResult: Result<DAppOperationConfirmModel, Error>) {
        modelResults.append(modelResult)
        modelExpectation.fulfill()
    }

    func didReceive(feeResult: Result<FeeOutputModel, Error>) {
        feeResults.append(feeResult)
        feeExpectation.fulfill()
    }

    func didReceive(priceResult _: Result<PriceData?, Error>) {}

    func didReceive(responseResult: Result<DAppOperationResponse, Error>, for _: DAppOperationRequest) {
        responseResults.append(responseResult)
        responseExpectation.fulfill()
    }

    func didReceive(txDetailsResult _: Result<JSON, Error>) {}
}

final class DAppFailingMetadataHashFactoryStub: MetadataHashOperationFactoryProtocol {
    let error: Error

    init(error: Error) {
        self.error = error
    }

    func createCheckMetadataHashWrapper(
        for _: ChainModel,
        connection _: JSONRPCEngine,
        runtimeProvider _: RuntimeCodingServiceProtocol
    ) -> CompoundOperationWrapper<Data?> {
        .createWithError(error)
    }
}

/// Keeps the metadata hash, and with it the whole setup of the confirmation, waiting until released.
final class DAppSuspendedMetadataHashFactoryStub: MetadataHashOperationFactoryProtocol {
    private let gate = DispatchSemaphore(value: 0)

    func release() {
        gate.signal()
    }

    func createCheckMetadataHashWrapper(
        for _: ChainModel,
        connection _: JSONRPCEngine,
        runtimeProvider _: RuntimeCodingServiceProtocol
    ) -> CompoundOperationWrapper<Data?> {
        let operation = ClosureOperation<Data?> {
            self.gate.wait()
            self.gate.signal()

            return nil
        }

        return CompoundOperationWrapper(targetOperation: operation)
    }
}
