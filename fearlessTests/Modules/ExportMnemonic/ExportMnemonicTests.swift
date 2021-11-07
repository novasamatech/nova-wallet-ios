import XCTest
@testable import fearless
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

        let sharingExpectation = XCTestExpectation()

        stub(wireframe) { stub in
            when(stub).present(viewModel: any(), style: any(), from: any()).then { (viewModel, _, _) in
                viewModel.actions.first?.handler?()
            }

            when(stub).share(source: any(), from: any(), with: any()).then { _ in
                sharingExpectation.fulfill()
            }
        }

        let presenter = ExportMnemonicPresenter(localizationManager: LocalizationManager.shared)

        let interactor = ExportMnemonicInteractor(
            metaAccount: metaAccount,
            chain: chain,
            keystore: keychain,
            operationManager: OperationManagerFacade.sharedManager
        )

        presenter.view = view
        presenter.wireframe = wireframe
        presenter.interactor = interactor

        interactor.presenter = presenter

        presenter.setup()

        // then

        wait(for: [setupExpectation], timeout: Constants.defaultExpectationDuration)

        // when

        presenter.activateExport()

        // then

        wait(for: [sharingExpectation], timeout: Constants.defaultExpectationDuration)

        XCTAssertEqual(metaAccount, presenter.exportData?.metaAccount)
        XCTAssertEqual(chain, presenter.exportData?.chain)
        XCTAssertEqual(derivationPath, presenter.exportData?.derivationPath)
    }
}
