import XCTest
@testable import novawallet
import SoraFoundation
import Cuckoo

class AdvancedWalletTests: XCTestCase {

    func testApplySettings() {
        // given

        let view = MockAdvancedWalletViewProtocol()
        let wireframe = MockAdvancedWalletWireframeProtocol()

        let substrateSettings = AdvancedNetworkTypeSettings(
            availableCryptoTypes: MultiassetCryptoType.allCases,
            selectedCryptoType: .sr25519,
            derivationPath: nil
        )

        let settings = AdvancedWalletSettings.combined(
            substrateSettings: substrateSettings,
            ethereumDerivationPath: DerivationPathConstants.defaultEthereum
        )

        let delegate = MockAdvancedWalletSettingsDelegate()

        let presenter = AdvancedWalletPresenter(
            wireframe: wireframe,
            localizationManager: LocalizationManager.shared,
            secretSource: .mnemonic,
            settings: settings,
            delegate: delegate
        )

        presenter.view = view

        // when

        var substrateDPViewModel: InputViewModelProtocol?
        var ethereumDPViewModel: InputViewModelProtocol?

        stub(view) { stub in
            when(stub).setSubstrateDerivationPath(viewModel: any()).then { viewModel in
                substrateDPViewModel = viewModel
            }

            when(stub).setEthereumDerivationPath(viewModel: any()).then { viewModel in
                ethereumDPViewModel = viewModel
            }

            when(stub).setSubstrateCrypto(viewModel: any()).thenDoNothing()

            when(stub).setEthreumCrypto(viewModel: any()).thenDoNothing()

            when(stub).didCompleteCryptoTypeSelection().thenDoNothing()
        }

        var actualSettings: AdvancedWalletSettings?

        stub(delegate) { stub in
            when(stub).didReceiveNewAdvanced(walletSettings: any()).then { newSettings in
                actualSettings = newSettings
            }
        }

        let completionExpectation = XCTestExpectation()

        stub(wireframe) { stub in
            when(stub).complete(from: any()).then { _ in
                completionExpectation.fulfill()
            }
        }

        presenter.setup()

        let expectedSubstrateCryptoType = MultiassetCryptoType.ed25519

        presenter.modalPickerDidSelectModelAtIndex(Int(expectedSubstrateCryptoType.rawValue), context: nil)

        let expectedSubstrateDP = "//work//hard"
        let expectedEthereumDP = "//1/2/3"

        _ = substrateDPViewModel?.inputHandler.didReceiveReplacement(
            expectedSubstrateDP,
            for: NSRange(location: 0, length: 0)
        )

        _ = ethereumDPViewModel?.inputHandler.didReceiveReplacement(
            expectedEthereumDP,
            for: NSRange(location: 0, length: DerivationPathConstants.defaultEthereum.count)
        )

        presenter.apply()

        // then

        wait(for: [completionExpectation], timeout: 1.0)

        if case .combined(let actualSubstrateSettings, let actualEthereumDP) = actualSettings {
            XCTAssertEqual(actualSubstrateSettings.selectedCryptoType, expectedSubstrateCryptoType)
            XCTAssertEqual(actualSubstrateSettings.derivationPath, expectedSubstrateDP)
            XCTAssertEqual(actualEthereumDP, expectedEthereumDP)
        } else {
            XCTFail("Unexpected settings")
        }

        verify(view, times(1)).didCompleteCryptoTypeSelection()
    }
}
