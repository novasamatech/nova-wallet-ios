import XCTest
@testable import novawallet
import SoraKeystore
import SoraFoundation
import RobinHood
import Cuckoo

class ExportMnemonicTests: XCTestCase {
    func testSuccessfullExport() throws {
        // given

        let keychain = InMemoryKeychain()
        let operationQueue = OperationQueue()

        let storageFacade = UserDataStorageTestFacade()
        let walletSettings = SelectedWalletSettings(storageFacade: storageFacade, operationQueue: operationQueue)
        let chain = ChainModelGenerator.generateChain(generatingAssets: 1, addressPrefix: 2)

        let derivationPath = "//some//work"

        try AccountCreationHelper.createMetaAccountFromMnemonic(
            cryptoType: .sr25519,
            derivationPath: derivationPath,
            keychain: keychain,
            settings: walletSettings
        )

        let metaAccount = walletSettings.value!

        // when

        let view = MockExportGenericViewProtocol()

        let setupExpectation = XCTestExpectation()

        stub(view) { stub in
            when(stub).set(viewModel: any()).then { _ in
                setupExpectation.fulfill()
            }
        }

        let wireframe = MockExportMnemonicWireframeProtocol()

        let completionExpectation = XCTestExpectation()

        stub(wireframe) { stub in
            when(stub).openConfirmationForMnemonic(any(), from: any()).then { _ in
                completionExpectation.fulfill()
            }
        }

        let interactor = ExportMnemonicInteractor(
            metaAccount: metaAccount,
            chain: chain,
            keystore: keychain,
            operationManager: OperationManagerFacade.sharedManager
        )

        let presenter = ExportMnemonicPresenter(
            interactor: interactor,
            wireframe: wireframe,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view
        interactor.presenter = presenter

        presenter.setup()

        // then

        wait(for: [setupExpectation], timeout: Constants.defaultExpectationDuration)

        // when

        presenter.activateExport()

        // then

        wait(for: [completionExpectation], timeout: Constants.defaultExpectationDuration)

        XCTAssertEqual(metaAccount, presenter.exportData?.metaAccount)
        XCTAssertEqual(chain, presenter.exportData?.chain)
        XCTAssertEqual(derivationPath, presenter.exportData?.derivationPath)
    }
}
