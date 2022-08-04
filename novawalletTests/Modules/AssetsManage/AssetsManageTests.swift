import XCTest
@testable import novawallet
import SoraKeystore
import Cuckoo

class AssetsManageTests: XCTestCase {
    func testSetupAndSave() {
        // given

        let view = MockAssetsManageViewProtocol()
        let wireframe = MockAssetsManageWireframeProtocol()

        let settingsManager = InMemorySettingsManager()
        settingsManager.hidesZeroBalances = true

        let eventCenter = MockEventCenterProtocol()

        let interactor = AssetsManageInteractor(settingsManager: settingsManager, eventCenter: eventCenter)
        let presenter = AssetsManagePresenter(interactor: interactor, wireframe: wireframe)

        presenter.view = view
        interactor.presenter = presenter

        // when

        var receivedViewModel: AssetsManageViewModel?
        let expectedViewModel = AssetsManageViewModel(hideZeroBalances: true, canApply: false)

        let setupCompletion = XCTestExpectation()

        stub(view) { stub in
            stub.didReceive(viewModel: any()).then { viewModel in
                receivedViewModel = viewModel

                setupCompletion.fulfill()
            }
        }

        presenter.setup()

        // then

        wait(for: [setupCompletion], timeout: 1.0)

        XCTAssertEqual(receivedViewModel, expectedViewModel)

        // when

        let closeExpectation = XCTestExpectation()

        stub(view) { stub in
            stub.didReceive(viewModel: any()).thenDoNothing()
        }

        stub(wireframe) { stub in
            stub.close(view: any()).then { _ in
                closeExpectation.fulfill()
            }
        }

        let notificationExpectation = XCTestExpectation()

        stub(eventCenter) { stub in
            stub.notify(with: any()).then { event in
                notificationExpectation.fulfill()
            }
        }

        presenter.changeHideZeroBalances(value: false)
        presenter.apply()

        // then

        wait(for: [closeExpectation, notificationExpectation], timeout: 1.0)

        XCTAssertEqual(settingsManager.hidesZeroBalances, false)
    }
}
