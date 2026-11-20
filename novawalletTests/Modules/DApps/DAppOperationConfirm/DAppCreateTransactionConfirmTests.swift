import BigInt
import Cuckoo
import Foundation_iOS
@testable import novawallet
import NovaAnalytics
import Operation_iOS
import SubstrateSdk
import XCTest

final class DAppCreateTransactionConfirmTests: XCTestCase {
    private typealias ExtensionId = Extrinsic.TransactionExtensionId

    func testConfirmationReturnsSignedExtrinsic() throws {
        // given

        let runtime = try ExtrinsicGoldenRuntime.westend()
        let fixture = try DAppTxPayloadFixture.transfer(runtime: runtime)
        let setup = try makeSetup(runtime: runtime, fixture: fixture)

        waitForLoadedConfirmation(of: setup)

        // when

        let response = try confirmAndWaitResponse(of: setup)

        // then

        XCTAssertNil(response.signature)
        XCTAssertNil(response.modifiedTransaction)

        guard case let .success(extrinsicData) = response.createTransactionResult else {
            XCTFail("Signed extrinsic expected")
            return
        }

        let extrinsic = try runtime.decodeExtrinsic(extrinsicData.toHex(includePrefix: true))
        let signed = try XCTUnwrap(extrinsic.getSignedExtrinsic())

        XCTAssertEqual(try runtime.encodeCall(signed.call), fixture.callData)
        XCTAssertEqual(signed.signature.extra.getNonce(), ExtrinsicGolden.nonce)
        XCTAssertEqual(signed.signature.extra.getEra(), ExtrinsicGolden.era)

        XCTAssertEqual(
            signed.signature.address.arrayValue?.last?.stringValue,
            ExtrinsicGolden.senderId.toHex(includePrefix: true)
        )

        let context = try XCTUnwrap(
            DAppSignAnalyticsContext(request: setup.request, type: .createTransaction(chain: setup.chain))
        )

        XCTAssertEqual(context.method.stringValue, "polkadot_createTransaction")
        XCTAssertEqual(setup.presenter.signOutcomeEvent(for: .success(response), context: context).name, .signApproved)
    }

    func testRejectionIsReportedWithoutResult() throws {
        // given

        let runtime = try ExtrinsicGoldenRuntime.westend()
        let setup = try makeSetup(runtime: runtime, fixture: DAppTxPayloadFixture.transfer(runtime: runtime))

        waitForLoadedConfirmation(of: setup)

        // when

        let response = try waitResponse(of: setup) { setup.presenter.reject() }

        // then

        XCTAssertNil(response.signature)
        XCTAssertNil(response.createTransactionResult)

        let context = try XCTUnwrap(
            DAppSignAnalyticsContext(request: setup.request, type: .createTransaction(chain: setup.chain))
        )

        XCTAssertEqual(setup.presenter.signOutcomeEvent(for: .success(response), context: context).name, .signRejected)
    }

    func testPayloadThatFailsVerificationIsExplainedAndAnsweredWithItsError() throws {
        let runtime = try ExtrinsicGoldenRuntime.westend()

        var anotherRuntimeValues = DAppTxPayloadFixture.Values()
        anotherRuntimeValues.specVersion = runtime.codingFactory.specVersion + 1

        var anotherChain = try DAppTxPayloadFixture.transfer(runtime: runtime)
        anotherChain.genesisHash = "0x91b171bb158e2d3848fa23a9f1c25182fb8e20313b2c1eb49219da7a70ce90c3"

        let invalidFixtures = [
            try DAppTxPayloadFixture.transfer(runtime: runtime, values: anotherRuntimeValues),
            try DAppTxPayloadFixture.transfer(runtime: runtime).removing("CheckWeight").replacing(
                ExtensionId.nonce,
                extra: Data([0x1C, 0x00])
            ),
            anotherChain
        ]

        // the dApp gets the failure whether the user confirms or rejects after reading the alert
        let userActions: [(DAppOperationConfirmPresenter) -> Void] = [{ $0.confirm() }, { $0.reject() }]

        for fixture in invalidFixtures {
            for userAction in userActions {
                // given

                let setup = try makeSetup(runtime: runtime, fixture: fixture)

                // when

                waitForVerificationAlert(of: setup)

                let response = try waitResponse(of: setup) { userAction(setup.presenter) }

                // then

                verify(setup.view, never()).didReceive(confirmationViewModel: any())

                guard case let .failure(error) = response.createTransactionResult else {
                    XCTFail("Verification failure expected")
                    return
                }

                XCTAssertEqual(error.name, "DecodeError")
                XCTAssertTrue(error.responseMessage.hasPrefix("DecodeError: "))

                let context = try XCTUnwrap(
                    DAppSignAnalyticsContext(request: setup.request, type: .createTransaction(chain: setup.chain))
                )

                XCTAssertEqual(
                    setup.presenter.signOutcomeEvent(for: .success(response), context: context).name,
                    .signFailed
                )
            }
        }
    }

    func testGeneralTransactionForVaultWalletIsAnsweredWithSignerUnavailable() throws {
        // given

        let runtime = try ExtrinsicGoldenRuntime.westendV16(customization: .init(formats: [5]))
        let fixture = try DAppTxPayloadFixture.transfer(runtime: runtime)
        let setup = try makeSetup(runtime: runtime, fixture: fixture, walletType: .polkadotVault)

        // when

        // the signer is known once the extrinsic is built for the fee
        waitForVerificationAlert(of: setup)

        let response = try confirmAndWaitResponse(of: setup)

        // then

        guard case let .failure(error) = response.createTransactionResult else {
            XCTFail("Verification failure expected")
            return
        }

        XCTAssertEqual(error.name, "SignerUnavailable")
    }

    func testGeneralTransactionIsSignedBySecretsWallet() throws {
        // given

        let runtime = try ExtrinsicGoldenRuntime.westendV16(customization: .init(formats: [5]))
        let fixture = try DAppTxPayloadFixture.transfer(runtime: runtime)
        let setup = try makeSetup(runtime: runtime, fixture: fixture)

        waitForLoadedConfirmation(of: setup)

        // when

        let response = try confirmAndWaitResponse(of: setup)

        // then

        guard case let .success(extrinsicData) = response.createTransactionResult else {
            XCTFail("Signed extrinsic expected")
            return
        }

        guard
            case let .generalTransaction(general) = try runtime.decodeExtrinsic(
                extrinsicData.toHex(includePrefix: true)
            ) else {
            XCTFail("General transaction expected")
            return
        }

        XCTAssertEqual(try runtime.encodeCall(general.call), fixture.callData)
        XCTAssertEqual(general.explicits.getNonce(), ExtrinsicGolden.nonce)
    }

    func testWatchOnlyWalletKeepsItsSigningError() throws {
        // given

        let runtime = try ExtrinsicGoldenRuntime.westend()

        let setup = try makeSetup(
            runtime: runtime,
            fixture: DAppTxPayloadFixture.transfer(runtime: runtime),
            walletType: .watchOnly,
            signingWrapperFactory: NoKeysSigningWrapperFactoryStub()
        )

        let presenter = MockDAppOperationConfirmInteractorOutputProtocol()
        let feeExpectation = XCTestExpectation()
        let responseExpectation = XCTestExpectation()

        var responseResult: Result<DAppOperationResponse, Error>?

        stub(presenter) { stub in
            when(stub.didReceive(modelResult: any())).thenDoNothing()
            when(stub.didReceive(priceResult: any())).thenDoNothing()

            when(stub.didReceive(feeResult: any())).then { _ in
                feeExpectation.fulfill()
            }

            when(stub.didReceive(responseResult: any(), for: any())).then { result, _ in
                responseResult = result
                responseExpectation.fulfill()
            }
        }

        setup.interactor.presenter = presenter
        setup.interactor.setup()

        wait(for: [feeExpectation], timeout: 10)

        // when

        setup.interactor.confirm()

        // then

        wait(for: [responseExpectation], timeout: 10)

        guard case let .failure(error) = responseResult else {
            XCTFail("Signing error expected")
            return
        }

        XCTAssertTrue(error.isWatchOnlySigning)
    }

    func testDetailsShowWhatWalletDecoded() throws {
        // given

        let runtime = try ExtrinsicGoldenRuntime.westend()
        let fixture = try DAppTxPayloadFixture.transfer(runtime: runtime).removing(ExtensionId.txPayment)
        let setup = try makeSetup(runtime: runtime, fixture: fixture)

        waitForLoadedConfirmation(of: setup)

        let detailsExpectation = XCTestExpectation()
        var receivedDetails: JSON?

        stub(setup.wireframe) { stub in
            when(stub.showTxDetails(from: any(), json: any())).then { _, json in
                receivedDetails = json
                detailsExpectation.fulfill()
            }
        }

        // when

        setup.presenter.activateTxDetails()

        // then

        wait(for: [detailsExpectation], timeout: 10)

        let details = try XCTUnwrap(receivedDetails)

        XCTAssertEqual(details.method?.callName?.stringValue, "transfer_keep_alive")
        XCTAssertEqual(details.extrinsicVersion, .unsignedIntValue(4))
        XCTAssertEqual(details.extensions?.CheckNonce?.extra?.stringValue, "7")
        XCTAssertEqual(details.walletExtensions?.arrayValue, [.stringValue(ExtensionId.txPayment)])
    }
}

private extension DAppCreateTransactionConfirmTests {
    struct Setup {
        let view: MockDAppOperationConfirmViewProtocol
        let wireframe: MockDAppOperationConfirmWireframeProtocol
        let delegate: MockDAppOperationConfirmDelegate
        let presenter: DAppOperationConfirmPresenter
        let interactor: DAppCreateTransactionConfirmInteractor
        let request: DAppOperationRequest
        let chain: ChainModel
    }

    func makeSetup(
        runtime: ExtrinsicGoldenRuntime,
        fixture: DAppTxPayloadFixture,
        walletType: MetaAccountModelType = .secrets,
        signingWrapperFactory: SigningWrapperFactoryProtocol = DummySigningWrapperFactory()
    ) throws -> Setup {
        let chain = try ExtrinsicGoldenRuntime.makeChain()

        let wallet = MetaAccountModel(
            metaId: UUID().uuidString,
            name: "Test",
            substrateAccountId: ExtrinsicGolden.senderId,
            substrateCryptoType: 0,
            substratePublicKey: ExtrinsicGolden.senderId,
            ethereumAddress: nil,
            ethereumPublicKey: nil,
            chainAccounts: [],
            type: walletType,
            multisig: nil
        )

        let account = try XCTUnwrap(wallet.fetch(for: chain.accountRequest()))

        let request = DAppOperationRequest(
            transportName: DAppTransports.polkadotExtension,
            identifier: UUID().uuidString,
            wallet: wallet,
            accountId: account.accountId,
            dApp: "Test",
            dAppIcon: nil,
            operationData: try fixture.makeRequestJSON()
        )

        let runtimeProvider = MockRuntimeProviderProtocol()

        stub(runtimeProvider) { stub in
            stub.fetchCoderFactoryOperation().then {
                BaseOperation.createWithResult(runtime.codingFactory)
            }

            stub.chainId.get.thenReturn(chain.chainId)
        }

        let connection = MockConnection()

        stub(connection.internalConnection) { stub in
            when(
                stub.callMethod(any(), params: any(), options: any(), completion: any())
            ).then { (_, _: [String]?, _, completion: ((Result<RuntimeDispatchInfo, Error>) -> Void)?) in
                let fee = RuntimeDispatchInfo(fee: "1", weight: .init(refTime: 32, proofSize: 0))

                DispatchQueue.global().async {
                    completion?(.success(fee))
                }

                return 0
            }
        }

        let operationQueue = OperationQueue()
        let storageFacade = SubstrateStorageTestFacade()

        let extrinsicFactory = DAppTxPayloadExtrinsicOperationFactory(
            payload: try request.operationData.map(to: PolkadotExtensionTxPayload.self),
            chain: chain,
            runtimeProvider: runtimeProvider,
            connection: connection,
            resolver: DAppTxPayloadExtensionResolver(),
            metadataHashOperationFactory: DAppMetadataHashFactoryStub(metadataHash: nil),
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

        let extrinsicFeeHost = ExtrinsicFeeEstimatorHost(
            account: account,
            chain: chain,
            connection: connection,
            runtimeProvider: runtimeProvider,
            userStorageFacade: UserDataStorageTestFacade(),
            substrateStorageFacade: storageFacade,
            operationQueue: operationQueue
        )

        let feeOperationFactory = ExtrinsicProxyOperationFactory(
            proxy: extrinsicFactory,
            runtimeRegistry: runtimeProvider,
            engine: connection,
            feeEstimationRegistry: ExtrinsicFeeEstimationRegistry(
                chain: chain,
                estimatingWrapperFactory: ExtrinsicFeeEstimatingWrapperFactory(
                    host: extrinsicFeeHost,
                    customFeeEstimatorFactory: AssetConversionFeeEstimatingFactory(host: extrinsicFeeHost)
                ),
                feeInstallingWrapperFactory: AssetConversionFeeInstallingFactory(host: extrinsicFeeHost)
            ),
            operationManager: OperationManager(operationQueue: operationQueue),
            usesStateCallForFee: chain.feeViaRuntimeCall
        )

        let interactor = DAppCreateTransactionConfirmInteractor(
            request: request,
            chain: chain,
            account: account,
            extrinsicFactory: extrinsicFactory,
            feeOperationFactory: feeOperationFactory,
            signingWrapperFactory: signingWrapperFactory,
            priceProviderFactory: PriceProviderFactoryStub(priceData: nil),
            currencyManager: CurrencyManagerStub(),
            operationQueue: operationQueue
        )

        let view = MockDAppOperationConfirmViewProtocol()
        let wireframe = MockDAppOperationConfirmWireframeProtocol()
        let delegate = MockDAppOperationConfirmDelegate()

        let presenter = DAppOperationConfirmPresenter(
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

        return Setup(
            view: view,
            wireframe: wireframe,
            delegate: delegate,
            presenter: presenter,
            interactor: interactor,
            request: request,
            chain: chain
        )
    }

    func waitForLoadedConfirmation(of setup: Setup) {
        let setupExpectation = XCTestExpectation()
        let feeExpectation = XCTestExpectation()

        stub(setup.view) { stub in
            when(stub.didReceive(feeViewModel: any())).then { viewModel in
                if case .loaded = viewModel {
                    feeExpectation.fulfill()
                }
            }

            when(stub.didReceive(confirmationViewModel: any())).then { _ in
                setupExpectation.fulfill()
            }
        }

        setup.presenter.setup()

        wait(for: [setupExpectation, feeExpectation], timeout: 10)
    }

    func waitForVerificationAlert(of setup: Setup) {
        let alertExpectation = XCTestExpectation()

        stub(setup.view) { stub in
            when(stub.didReceive(feeViewModel: any())).thenDoNothing()
            when(stub.didReceive(confirmationViewModel: any())).thenDoNothing()
        }

        stub(setup.wireframe) { stub in
            when(stub.present(viewModel: any(), style: any(), from: any())).then { _ in
                alertExpectation.fulfill()
            }
        }

        setup.presenter.setup()

        wait(for: [alertExpectation], timeout: 10)
    }

    func confirmAndWaitResponse(of setup: Setup) throws -> DAppOperationResponse {
        try waitResponse(of: setup) { setup.presenter.confirm() }
    }

    func waitResponse(of setup: Setup, after action: () -> Void) throws -> DAppOperationResponse {
        let closeExpectation = XCTestExpectation()
        let confirmationExpectation = XCTestExpectation()

        var receivedResponse: DAppOperationResponse?

        stub(setup.wireframe) { stub in
            when(stub.close(view: any())).then { _ in
                closeExpectation.fulfill()
            }
        }

        stub(setup.delegate) { stub in
            when(stub.didReceiveConfirmationResponse(any(), for: any())).then { response, _ in
                receivedResponse = response
                confirmationExpectation.fulfill()
            }
        }

        action()

        wait(for: [confirmationExpectation, closeExpectation], timeout: 10)

        return try XCTUnwrap(receivedResponse)
    }
}

private final class NoKeysSigningWrapperFactoryStub: SigningWrapperFactoryProtocol {
    func createSigningWrapper(giftSigningData _: GiftSigningData) -> SigningWrapperProtocol {
        NoKeysSigningWrapper()
    }

    func createSigningWrapper(
        for _: String,
        accountResponse _: ChainAccountResponse
    ) -> SigningWrapperProtocol {
        NoKeysSigningWrapper()
    }

    func createSigningWrapper(for _: MetaEthereumAccountResponse) -> SigningWrapperProtocol {
        NoKeysSigningWrapper()
    }

    func createEthereumSigner(for _: MetaEthereumAccountResponse) -> SignatureCreatorProtocol {
        NoKeysSigningWrapper()
    }
}
