import XCTest
@testable import novawallet
import Cuckoo
import SoraFoundation

class UsernameSetupTests: XCTestCase {

    func testSuccessfullUsernameInput() {
        // given

        let view = MockUsernameSetupViewProtocol()
        let wireframe = MockUsernameSetupWireframeProtocol()

        let interactor = UsernameSetupInteractor()

        let presenter = UsernameSetupPresenter()
        presenter.view = view
        presenter.wireframe = wireframe
        presenter.interactor = interactor
        interactor.presenter = presenter

        let expectedName = "test name"

        var receivedViewModel: InputViewModelProtocol?
        var resultName: String?

        let inputViewModelExpectation = XCTestExpectation()
        let proceedExpectation = XCTestExpectation()

        stub(view) { stub in
            when(stub).setInput(viewModel: any()).then { viewModel in
                receivedViewModel = viewModel
                inputViewModelExpectation.fulfill()
            }
        }

        stub(wireframe) { stub in
            when(stub).proceed(from: any(), walletName: any()).then { (_, walletName) in
                resultName = walletName

                proceedExpectation.fulfill()
            }

            when(stub).present(viewModel: any(),
                               style: any(),
                               from: any()).then { (viewModel, _, _) in
                viewModel.actions.first?.handler?()

            }
        }

        // when

        presenter.setup()

        // then

        wait(
            for: [inputViewModelExpectation],
            timeout: Constants.defaultExpectationDuration
        )

        // when

        guard
            let accepted = receivedViewModel?.inputHandler
                .didReceiveReplacement(
                    expectedName,
                    for: NSRange(location: 0, length: 0)
                ), accepted else {
            XCTFail("Unexpected empty view model")
            return
        }

        presenter.proceed()

        // then

        wait(for: [proceedExpectation], timeout: Constants.defaultExpectationDuration)

        XCTAssertEqual(expectedName, resultName)
    }
}
