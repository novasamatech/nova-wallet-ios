import XCTest
@testable import novawallet
import IrohaCrypto
import SoraFoundation
import Cuckoo

class AccountCreateTests: XCTestCase {

    func testSuccessfullAccountCreation() {
        // given

        let view = MockAccountCreateViewProtocol()
        let wireframe = MockAccountCreateWireframeProtocol()

        let mnemonicCreator = IRMnemonicCreator()
        let interactor = AccountCreateInteractor(mnemonicCreator: mnemonicCreator)

        let name = "myname"
        let presenter = AccountCreatePresenter(
            walletName: name,
            localizationManager: LocalizationManager.shared
        )
        presenter.view = view
        presenter.wireframe = wireframe
        presenter.interactor = interactor
        interactor.presenter = presenter

        let setupExpectation = XCTestExpectation()

        stub(view) { stub in
            when(stub).isSetup.get.thenReturn(false, true)

            when(stub).set(mnemonic: any()).then { _ in
                setupExpectation.fulfill()
            }

            when(stub).displayMnemonic().thenDoNothing()
        }

        let expectation = XCTestExpectation()

        var receivedRequest: MetaAccountCreationRequest?

        stub(wireframe) { stub in
            when(stub).confirm(from: any(), request: any(), metadata: any()).then { (_, request, _) in
                receivedRequest = request
                expectation.fulfill()
            }
        }

        // when

        presenter.setup()

        wait(for: [setupExpectation], timeout: Constants.defaultExpectationDuration)

        presenter.proceed()

        // then

        wait(for: [expectation], timeout: Constants.defaultExpectationDuration)

        XCTAssertEqual(receivedRequest?.username, name)
    }
}
