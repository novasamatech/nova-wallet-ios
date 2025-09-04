import XCTest
@testable import novawallet
import NovaCrypto
import Foundation_iOS
import Cuckoo

class AccountCreateTests: XCTestCase {

    func testSuccessfullAccountCreation() {
        // given

        let view = MockAccountCreateViewProtocol()
        let wireframe = MockAccountCreateWireframeProtocol()

        let interactor = AccountCreateInteractor(walletRequestFactory: WalletCreationRequestFactory())
        
        let localizationManager = LocalizationManager.shared
        let checkboxListViewModelFactory = CheckboxListViewModelFactory(localizationManager: localizationManager)
        let mnemonicViewModelFactory = MnemonicViewModelFactory(localizationManager: localizationManager)

        let name = "myname"
        let presenter = AccountCreatePresenter(
            interactor: interactor,
            wireframe: wireframe,
            walletName: name,
            localizationManager: localizationManager,
            checkboxListViewModelFactory: checkboxListViewModelFactory,
            mnemonicViewModelFactory: mnemonicViewModelFactory
        )
        presenter.view = view
        interactor.presenter = presenter

        let setupCheckboxesExpectation = XCTestExpectation()
        let setupMnemonicExpectation = XCTestExpectation()

        stub(view) { stub in
            when(stub.isSetup.get).thenReturn(false, true)

            when(stub.update(with: any())).then { _ in
                setupMnemonicExpectation.fulfill()
            }
            
            when(stub.update(using: any())).then { _ in
                setupCheckboxesExpectation.fulfill()
            }
        }

        let expectation = XCTestExpectation()

        var receivedRequest: MetaAccountCreationRequest?

        stub(wireframe) { stub in
            when(stub.confirm(from: any(), request: any(), metadata: any())).then { (_, request, _) in
                receivedRequest = request
                expectation.fulfill()
            }
        }

        // when

        presenter.setup()
        
        interactor.provideMnemonic()

        wait(
            for: [
                setupMnemonicExpectation,
                setupCheckboxesExpectation
            ],
            timeout: Constants.defaultExpectationDuration
        )

        presenter.continueTapped()

        // then

        wait(for: [expectation], timeout: Constants.defaultExpectationDuration)

        XCTAssertEqual(receivedRequest?.username, name)
    }
}
