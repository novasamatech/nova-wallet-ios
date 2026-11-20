import Cuckoo
import Foundation_iOS
@testable import novawallet
import SubstrateSdk
import XCTest

/// The confirmation can't be built when the chain has lost its connection or runtime provider.
final class DAppBrowserConfirmationFallbackTests: XCTestCase {
    func testCreateTransactionIsAnsweredWhenConfirmationCantBeShown() throws {
        // given

        let setup = makeSetup(isConfirmationPresented: false)
        let chain = ChainModelGenerator.generateChain(generatingAssets: 1, addressPrefix: 42)

        var receivedResponse: DAppOperationResponse?
        var receivedTransport: String?

        stub(setup.interactor) { stub in
            when(stub.processConfirmation(response: any(), forTransport: any())).then { response, transport in
                receivedResponse = response
                receivedTransport = transport
            }
        }

        // when

        setup.presenter.didReceiveConfirmation(request: try makeRequest(), type: .createTransaction(chain: chain))

        // then

        guard case let .failure(error) = receivedResponse?.createTransactionResult else {
            XCTFail("The dApp must get a failure")
            return
        }

        XCTAssertEqual(error.name, "SignerUnavailable")
        XCTAssertEqual(receivedTransport, DAppTransports.polkadotExtension)
    }

    func testCreateTransactionIsLeftToConfirmationWhenItIsShown() throws {
        // given

        let setup = makeSetup(isConfirmationPresented: true)
        let chain = ChainModelGenerator.generateChain(generatingAssets: 1, addressPrefix: 42)

        // when

        setup.presenter.didReceiveConfirmation(request: try makeRequest(), type: .createTransaction(chain: chain))

        // then

        verify(setup.interactor, never()).processConfirmation(response: any(), forTransport: any())
    }

    func testOtherSigningTypesKeepTheirBehaviourWhenConfirmationCantBeShown() throws {
        // given

        let setup = makeSetup(isConfirmationPresented: false)
        let chain = ChainModelGenerator.generateChain(generatingAssets: 1, addressPrefix: 42)

        // when

        setup.presenter.didReceiveConfirmation(request: try makeRequest(), type: .extrinsic(chain: chain))
        setup.presenter.didReceiveConfirmation(request: try makeRequest(), type: .bytes(chain: chain))

        // then

        verify(setup.interactor, never()).processConfirmation(response: any(), forTransport: any())
    }
}

private extension DAppBrowserConfirmationFallbackTests {
    struct Setup {
        let presenter: DAppBrowserPresenter
        let interactor: MockDAppBrowserInteractorInputProtocol
    }

    func makeSetup(isConfirmationPresented: Bool) -> Setup {
        let interactor = MockDAppBrowserInteractorInputProtocol()
        let wireframe = MockDAppBrowserWireframeProtocol()

        stub(wireframe) { stub in
            when(
                stub.presentOperationConfirm(from: any(), request: any(), type: any(), delegate: any())
            ).thenReturn(isConfirmationPresented)
        }

        let presenter = DAppBrowserPresenter(
            interactor: interactor,
            wireframe: wireframe,
            localizationManager: LocalizationManager.shared
        )

        return Setup(presenter: presenter, interactor: interactor)
    }

    func makeRequest() throws -> DAppOperationRequest {
        let accountId = try XCTUnwrap(Data.random(of: 32))

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

        return DAppOperationRequest(
            transportName: DAppTransports.polkadotExtension,
            identifier: "1763625600000.7",
            wallet: wallet,
            accountId: accountId,
            dApp: "https://dapp.io",
            dAppIcon: nil,
            operationData: .null
        )
    }
}
