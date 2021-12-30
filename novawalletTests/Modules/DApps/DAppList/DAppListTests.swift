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

        let dAppProvider = SingleValueProviderStub(
            item: DAppListGenerator.createAnyDAppList()
        )

        let interactor = DAppListInteractor(
            walletSettings: walletSettings,
            eventCenter: EventCenter.shared,
            dAppProvider: AnySingleValueProvider(dAppProvider)
        )

        let presenter = DAppListPresenter(
            interactor: interactor,
            wireframe: wireframe,
            viewModelFactory: DAppListViewModelFactory(),
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view
        interactor.presenter = presenter

        // when

        let iconExpectation = XCTestExpectation()

        let stateExpectation = XCTestExpectation()

        var actualState: DAppListState? = nil

        stub(view) { stub in
            stub.didReceive(state: any()).then { state in
                guard case .loaded = state else {
                    return
                }

                actualState = state

                stateExpectation.fulfill()
            }

            stub.didCompleteRefreshing().thenDoNothing()

            stub.didReceiveAccount(icon: any()).then { _ in
                iconExpectation.fulfill()
            }
        }

        presenter.setup()

        // then

        wait(for: [iconExpectation, stateExpectation], timeout: 10.0)

        switch actualState {
        case .loading, .error, .none:
            XCTFail("Unexpected final state")
        case .loaded:
            break
        }
    }
}
