import XCTest
@testable import novawallet
import SoraKeystore
import Cuckoo

class DAppAuthConfirmTests: XCTestCase {

    func testSetup() throws {
        // given

        let view = MockDAppAuthConfirmViewProtocol()
        let wireframe = MockDAppAuthConfirmWireframeProtocol()
        let delegate = MockDAppAuthDelegate()

        let presenter = try performSetup(for: view, wireframe: wireframe, delegate: delegate)

        // when

        presenter.setup()

        // then

        verify(view, times(1)).didReceive(viewModel: any())
    }

    func testAllow() throws {
        // given

        let view = MockDAppAuthConfirmViewProtocol()
        let wireframe = MockDAppAuthConfirmWireframeProtocol()
        let delegate = MockDAppAuthDelegate()

        let presenter = try performSetup(for: view, wireframe: wireframe, delegate: delegate)

        var actualResponse: DAppAuthResponse?

        stub(delegate) { stub in
            stub.didReceiveAuthResponse(any(), for: any()).then { (response, _) in
                actualResponse = response
            }
        }

        // when

        presenter.setup()

        presenter.allow()

        // then

        verify(delegate, times(1)).didReceiveAuthResponse(any(), for: any())
        verify(wireframe, times(1)).close(from: any())

        XCTAssertEqual(actualResponse?.approved, true)
    }

    func testDeny() throws {
        // given

        let view = MockDAppAuthConfirmViewProtocol()
        let wireframe = MockDAppAuthConfirmWireframeProtocol()
        let delegate = MockDAppAuthDelegate()

        let presenter = try performSetup(for: view, wireframe: wireframe, delegate: delegate)

        var actualResponse: DAppAuthResponse?

        stub(delegate) { stub in
            stub.didReceiveAuthResponse(any(), for: any()).then { (response, _) in
                actualResponse = response
            }
        }

        // when

        presenter.setup()

        presenter.deny()

        // then

        verify(delegate, times(1)).didReceiveAuthResponse(any(), for: any())
        verify(wireframe, times(1)).close(from: any())

        XCTAssertEqual(actualResponse?.approved, false)
    }

    private func performSetup(
        for view: MockDAppAuthConfirmViewProtocol,
        wireframe: MockDAppAuthConfirmWireframeProtocol,
        delegate: MockDAppAuthDelegate
    ) throws -> DAppAuthConfirmPresenter {
        let keychain = InMemoryKeychain()

        let storageFacade = UserDataStorageTestFacade()
        let walletSettings = SelectedWalletSettings(
            storageFacade: storageFacade,
            operationQueue: OperationQueue()
        )

        try AccountCreationHelper.createMetaAccountFromMnemonic(
            cryptoType: .sr25519,
            keychain: keychain,
            settings: walletSettings
        )

        let request = DAppAuthRequest(
            transportName: DAppTransports.polkadotExtension,
            identifier: UUID().uuidString,
            wallet: walletSettings.value,
            origin: "DApp",
            dApp: "Test",
            dAppIcon: nil
        )

        let presenter = DAppAuthConfirmPresenter(
            wireframe: wireframe,
            request: request,
            delegate: delegate,
            viewModelFactory: DAppAuthViewModelFactory()
        )

        presenter.view = view

        stub(view) { stub in
            stub.didReceive(viewModel: any()).thenDoNothing()
        }

        stub(wireframe) { stub in
            stub.close(from: any()).thenDoNothing()
        }

        stub(delegate) { stub in
            stub.didReceiveAuthResponse(any(), for: any()).thenDoNothing()
        }

        return presenter
    }
}
