import XCTest
@testable import novawallet
import Cuckoo
import SoraKeystore
import SoraFoundation

class DAppBrowserTests: XCTestCase {
    let dAppURL = "https://polkadot.js.org/apps"

    let dAppChain = ChainModelGenerator.generateChain(
        generatingAssets: 2,
        addressPrefix: 42,
        hasCrowdloans: true
    )

    func testSetupCompletion() throws {
        // given

        let view = MockDAppBrowserViewProtocol()
        let wireframe = MockDAppBrowserWireframeProtocol()

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

        let chainRegistry = MockChainRegistryProtocol().applyDefault(for: [dAppChain])

        let interactor = DAppBrowserInteractor(
            userQuery: .query(string: dAppURL),
            wallet: walletSettings.value,
            chainRegistry: chainRegistry,
            operationQueue: OperationQueue()
        )

        let presenter = DAppBrowserPresenter(
            interactor: interactor,
            wireframe: wireframe,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view
        interactor.presenter = presenter

        // when

        var loadedModel: DAppBrowserModel?

        let loadingExpectation = XCTestExpectation()

        stub(view) { stub in
            when(stub).didReceive(viewModel: any()).then { viewModel in
                loadedModel = viewModel

                loadingExpectation.fulfill()
            }
        }

        presenter.setup()

        // then

        wait(for: [loadingExpectation], timeout: 10)

        XCTAssertEqual(loadedModel?.url, URL(string: dAppURL)!)

        if (interactor.state as? DAppBrowserWaitingAuthState) == nil {
            XCTFail("Waiting auth state expected after setup")
        }
    }
}
