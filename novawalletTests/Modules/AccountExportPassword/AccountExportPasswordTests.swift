import XCTest
@testable import novawallet
import SoraKeystore
import RobinHood
import SoraFoundation
import Cuckoo

class AccountExportPasswordTests: XCTestCase {
    func testSuccessfullExport() throws {
        // given

        let facade = UserDataStorageTestFacade()

        let walletSettings = SelectedWalletSettings(storageFacade: facade, operationQueue: OperationQueue())
        let keychain = InMemoryKeychain()

        try AccountCreationHelper.createMetaAccountFromMnemonic(
            cryptoType: .sr25519,
            keychain: keychain,
            settings: walletSettings
        )

        let metaAccount = walletSettings.value!
        let chain = ChainModelGenerator.generateChain(generatingAssets: 1, addressPrefix: 2)

        let view = MockAccountExportPasswordViewProtocol()
        let wireframe = MockAccountExportPasswordWireframeProtocol()

        let exportWrapper = KeystoreExportWrapper(keystore: keychain)
        let interactor = AccountExportPasswordInteractor(
            metaAccount: metaAccount,
            chain: chain,
            exportJsonWrapper: exportWrapper,
            operationManager: OperationManagerFacade.sharedManager
        )

        let presenter = AccountExportPasswordPresenter(
            interactor: interactor,
            wireframe: wireframe,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view
        interactor.presenter = presenter

        var inputViewModel: InputViewModelProtocol?
        var confirmationViewModel: InputViewModelProtocol?

        stub(view) { stub in
            when(stub).setPasswordInputViewModel(any()).then { viewModel in
                inputViewModel = viewModel
            }

            when(stub).setPasswordConfirmationViewModel(any()).then { viewModel in
                confirmationViewModel = viewModel
            }
        }

        let expectation = XCTestExpectation()

        stub(wireframe) { stub in
            when(stub).showJSONExport(any(), from: any()).then { _ in
                expectation.fulfill()
            }
        }

        // when

        presenter.setup()

        inputViewModel?.inputHandler.changeValue(to: Constants.validSrKeystorePassword)
        confirmationViewModel?.inputHandler.changeValue(to: Constants.validSrKeystorePassword)

        presenter.proceed()

        // then

        wait(for: [expectation], timeout: Constants.defaultExpectationDuration)
    }
}
