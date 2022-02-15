import XCTest
@testable import novawallet
import SoraKeystore
import SoraFoundation
import Cuckoo

class DAppListTests: XCTestCase {
    func testSuccessSetup() throws {
        // given

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

        let view = MockDAppListViewProtocol()
        let wireframe = MockDAppListWireframeProtocol()

        let interactor = DAppListInteractor(
            walletSettings: walletSettings,
            eventCenter: EventCenter.shared
        )

        let presenter = DAppListPresenter(
            interactor: interactor,
            wireframe: wireframe,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view
        interactor.presenter = presenter

        // when

        let iconExpectation = XCTestExpectation()

        stub(view) { stub in
            stub.didReceiveAccount(icon: any()).then { _ in
                iconExpectation.fulfill()
            }
        }

        presenter.setup()

        // then

        wait(for: [iconExpectation], timeout: 10.0)
    }
}
