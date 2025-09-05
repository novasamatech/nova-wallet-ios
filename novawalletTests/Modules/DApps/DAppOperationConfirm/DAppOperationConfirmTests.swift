import XCTest
@testable import novawallet
import NovaCrypto
import SubstrateSdk
import Keystore_iOS
import Foundation_iOS
import Cuckoo
import BigInt

class DAppOperationConfirmTests: XCTestCase {
    let extrinsicRequest = PolkadotExtensionExtrinsic(
        address: "3rBVRJQeQzmvsVH8QvwJafGVdRtHLTFTUdMRoyTmggnx6Qqh",
        blockHash: "0x2fad67977d3e2235f745f88f8c4149182f9ee717f871dd5aa66a336049417221",
        blockNumber: "0x00723632",
        era: "0x2503",
        genesisHash: "0x0bd72c1c305172e1275278aaeb3f161e02eccb7a819e63f62d47bd53a28189f8",
        method: "0x1001d177000000000000c29300000000000001",
        nonce: "0x0000000f",
        specVersion: BigUInt(9260).serialize().toHex(includePrefix: true),
        tip: "0x00000000000000000000000000000000",
        transactionVersion: "0x00000003",
        metadataHash: nil,
        assetId: nil,
        withSignedTransaction: nil,
        signedExtensions: [
            "CheckNonZeroSender",
            "CheckSpecVersion",
            "CheckTxVersion",
            "CheckGenesis",
            "CheckMortality",
            "CheckNonce",
            "CheckWeight",
            "ChargeTransactionPayment"
        ],
        version: 4
    )

    let bytesRequest = PolkadotExtensionPayload(
        address: "3rBVRJQeQzmvsVH8QvwJafGVdRtHLTFTUdMRoyTmggnx6Qqh",
        data: "0x00000000000000000000000000000000"
    )

    func testSignExtrinsic() throws {
        // given

        let view = MockDAppOperationConfirmViewProtocol()
        let wireframe = MockDAppOperationConfirmWireframeProtocol()

        let accountId = try extrinsicRequest.address.toAccountId()
        let addressPrefix = try SS58AddressFactory().type(fromAddress: extrinsicRequest.address)

        let wallet = MetaAccountModel(
            metaId: UUID().uuidString,
            name: "Test",
            substrateAccountId: accountId,
            substrateCryptoType: 0,
            substratePublicKey: accountId,
            ethereumAddress: nil,
            ethereumPublicKey: nil,
            chainAccounts: [],
            type: .secrets,
            multisig: nil
        )

        let chainId = try Data(hexString: extrinsicRequest.genesisHash).toHex()
        let chain = ChainModelGenerator.generateChain(
            defaultChainId: chainId,
            generatingAssets: 1,
            addressPrefix: addressPrefix.uint64Value,
            assetPresicion: 12,
            hasStaking: false,
            hasCrowdloans: false
        )

        let jsonData = try JSONEncoder().encode(extrinsicRequest)
        let jsonRequest = try JSONDecoder().decode(JSON.self, from: jsonData)

        let request = DAppOperationRequest(
            transportName: DAppTransports.polkadotExtension,
            identifier: UUID().uuidString,
            wallet: wallet,
            accountId: accountId,
            dApp: "Test",
            dAppIcon: nil,
            operationData: jsonRequest
        )

        let specVersion = BigUInt.fromHexString(extrinsicRequest.specVersion)!
        let txVersion = BigUInt.fromHexString(extrinsicRequest.transactionVersion)!

        let runtimeProvider = MockRuntimeProviderProtocol().applyDefault(
            for: chainId,
            specVersion: UInt32(specVersion),
            txVersion: UInt32(txVersion)
        )

        let connection = MockConnection()
        
        stub(connection.internalConnection) { stub in
            when(
                stub.callMethod(
                    any(),
                    params: any(),
                    options: any(),
                    completion: any()
                )
            ).then { (_, params: [String]?, _, completion: ((Result<RuntimeDispatchInfo, Error>) -> Void)?) in
                
                let fee = RuntimeDispatchInfo(fee: "1", weight: .init(refTime: 32, proofSize: 0))

                DispatchQueue.global().async {
                    completion?(.success(fee))
                }

                return 0
            }
        }

        let signingWrapperFactory = DummySigningWrapperFactory()
        let priceProvider = PriceProviderFactoryStub(priceData: nil)
        
        let operationQueue = OperationQueue()
        
        let  storageFacade = SubstrateStorageTestFacade()
        
        let extrinsicFeeHost = ExtrinsicFeeEstimatorHost(
            account: wallet.fetch(for: chain.accountRequest())!,
            chain: chain,
            connection: connection,
            runtimeProvider: runtimeProvider,
            userStorageFacade: UserDataStorageTestFacade(),
            substrateStorageFacade: storageFacade,
            operationQueue: operationQueue
        )
        
        let feeEstimationRegistry = ExtrinsicFeeEstimationRegistry(
            chain: chain,
            estimatingWrapperFactory: ExtrinsicFeeEstimatingWrapperFactory(
                host: extrinsicFeeHost,
                customFeeEstimatorFactory: AssetConversionFeeEstimatingFactory(host: extrinsicFeeHost)
            ),
            feeInstallingWrapperFactory: AssetConversionFeeInstallingFactory(host: extrinsicFeeHost)
        )
        
        let metadataHashFactory = MetadataHashOperationFactory(
            metadataRepositoryFactory: RuntimeMetadataRepositoryFactory(
                storageFacade: storageFacade
            ),
            operationQueue: operationQueue
        )

        let interactor = DAppOperationConfirmInteractor(
            request: request,
            chain: chain,
            runtimeProvider: runtimeProvider,
            feeEstimationRegistry: feeEstimationRegistry,
            connection: connection,
            signingWrapperFactory: signingWrapperFactory, 
            metadataHashFactory: metadataHashFactory,
            userStorageFacade: UserDataStorageTestFacade(),
            priceProviderFactory: priceProvider,
            currencyManager: CurrencyManagerStub(),
            operationQueue: operationQueue
        )

        let delegate = MockDAppOperationConfirmDelegate()

        let balanceViewModelFactory = BalanceViewModelFactoryFacade(
            priceAssetInfoFactory: PriceAssetInfoFactory(currencyManager: CurrencyManagerStub())
        )

        let presenter = DAppOperationConfirmPresenter(
            interactor: interactor,
            wireframe: wireframe,
            delegate: delegate,
            viewModelFactory: DAppOperationGenericConfirmViewModelFactory(chain: .left(chain)),
            balanceViewModelFacade: balanceViewModelFactory,
            chain: .left(chain),
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view
        interactor.presenter = presenter

        // when

        let feeExpectation = XCTestExpectation()
        let setupExpectation = XCTestExpectation()

        stub(view) { stub in
            when(stub.didReceive(feeViewModel: any())).then { viewModel in
                switch viewModel {
                case .loaded:
                    feeExpectation.fulfill()
                default:
                    break
                }
            }

            when(stub.didReceive(confirmationViewModel: any())).then { _ in
                setupExpectation.fulfill()
            }
        }

        presenter.setup()

        // then

        wait(for: [feeExpectation, setupExpectation], timeout: 10)

        // when

        let closeExpectation = XCTestExpectation()
        let confirmationExpectation = XCTestExpectation()

        stub(wireframe) { stub in
            when(stub.close(view: any())).then { _ in
                closeExpectation.fulfill()
            }
        }

        stub(delegate) { stub in
            when(stub.didReceiveConfirmationResponse(any(), for: any())).then { _ in
                confirmationExpectation.fulfill()
            }
        }

        presenter.confirm()

        // then

        wait(for: [confirmationExpectation, closeExpectation], timeout: 10.0)
    }

    func testSignBytes() throws {
        // given

        let view = MockDAppOperationConfirmViewProtocol()
        let wireframe = MockDAppOperationConfirmWireframeProtocol()

        let accountId = try bytesRequest.address.toAccountId()
        let addressPrefix = try SS58AddressFactory().type(fromAddress: bytesRequest.address)

        let wallet = MetaAccountModel(
            metaId: UUID().uuidString,
            name: "Test",
            substrateAccountId: accountId,
            substrateCryptoType: 0,
            substratePublicKey: accountId,
            ethereumAddress: nil,
            ethereumPublicKey: nil,
            chainAccounts: [],
            type: .secrets,
            multisig: nil
        )

        let chain = ChainModelGenerator.generateChain(
            generatingAssets: 1,
            addressPrefix: addressPrefix.uint64Value,
            assetPresicion: 12,
            hasStaking: false,
            hasCrowdloans: false
        )

        let jsonRequest = JSON.stringValue(bytesRequest.data)

        let signingWrapperFactory = DummySigningWrapperFactory()

        let request = DAppOperationRequest(
            transportName: DAppTransports.polkadotExtension,
            identifier: UUID().uuidString,
            wallet: wallet,
            accountId: accountId,
            dApp: "Test",
            dAppIcon: nil,
            operationData: jsonRequest
        )
        
        let serializationFactory = PolkadotExtensionMessageSignFactory()

        let interactor = DAppSignBytesConfirmInteractor(
            request: request,
            chain: chain,
            signingWrapperFactory: signingWrapperFactory,
            serializationFactory: serializationFactory,
            operationQueue: OperationQueue()
        )

        let delegate = MockDAppOperationConfirmDelegate()

        let balanceViewModelFacade = BalanceViewModelFactoryFacade(
            priceAssetInfoFactory: PriceAssetInfoFactory(currencyManager: CurrencyManagerStub())
        )

        let presenter = DAppOperationConfirmPresenter(
            interactor: interactor,
            wireframe: wireframe,
            delegate: delegate,
            viewModelFactory: DAppOperationBytesConfirmViewModelFactory(chain: .left(chain)),
            balanceViewModelFacade: balanceViewModelFacade,
            chain: .left(chain),
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view
        interactor.presenter = presenter

        // when

        let feeExpectation = XCTestExpectation()
        let setupExpectation = XCTestExpectation()

        stub(view) { stub in
            when(stub.didReceive(feeViewModel: any())).then { viewModel in
                switch viewModel {
                case .empty:
                    feeExpectation.fulfill()
                default:
                    break
                }
            }

            when(stub.didReceive(confirmationViewModel: any())).then { _ in
                setupExpectation.fulfill()
            }
        }

        presenter.setup()

        // then

        wait(for: [feeExpectation, setupExpectation], timeout: 10)

        // when

        let closeExpectation = XCTestExpectation()
        let confirmationExpectation = XCTestExpectation()

        stub(wireframe) { stub in
            when(stub.close(view: any())).then { _ in
                closeExpectation.fulfill()
            }
        }

        stub(delegate) { stub in
            when(stub.didReceiveConfirmationResponse(any(), for: any())).then { _ in
                confirmationExpectation.fulfill()
            }
        }

        presenter.confirm()

        // then

        wait(for: [confirmationExpectation, closeExpectation], timeout: 10.0)
    }
}
