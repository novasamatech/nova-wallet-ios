import XCTest
@testable import novawallet
import Keystore_iOS
import Cuckoo

final class SecurityLayerTests: XCTestCase {
    func testAppOverlayShownWhenInactive() {
        // given

        let wireframe = MockSecurityLayerWireframeProtocol()
        let presenter = SecurityLayerPresenter(wireframe: wireframe)

        let keystore = InMemoryKeychain()

        let applicationHandler = SecuredApplicationHandlerProxy()

        let interactor = SecurityLayerInteractor(
            presenter: presenter,
            applicationHandler: applicationHandler,
            keystore: keystore,
            inactivityDelay: TimeInterval.greatestFiniteMagnitude
        )

        // when

        interactor.setup()

        let showOverlayExpectation = XCTestExpectation()

        stub(wireframe) { stub in
            when(stub.showSecuringOverlay()).then {
                showOverlayExpectation.fulfill()
            }
        }

        applicationHandler.willResignActiveHandler(
            notification: Notification(name: UIApplication.willResignActiveNotification)
        )

        // then

        wait(for: [showOverlayExpectation], timeout: 1)

        // when

        let hideOverlayExpectation = XCTestExpectation()

        stub(wireframe) { stub in
            when(stub.hideSecuringOverlay()).then {
                hideOverlayExpectation.fulfill()
            }
        }

        applicationHandler.didBecomeActiveHandler(
            notification: Notification(name: UIApplication.didBecomeActiveNotification)
        )

        // then

        wait(for: [hideOverlayExpectation], timeout: 1)
    }

    func testPincodeIsRequestedWhenBackgroundTimeout() throws {
        // given

        let wireframe = MockSecurityLayerWireframeProtocol()
        let presenter = SecurityLayerPresenter(wireframe: wireframe)

        let keystore = InMemoryKeychain()

        try keystore.saveKey(Data(), with: KeystoreTagV2.pincode.rawValue)

        let applicationHandler = SecuredApplicationHandlerProxy()

        let interactor = SecurityLayerInteractor(
            presenter: presenter,
            applicationHandler: applicationHandler,
            keystore: keystore,
            inactivityDelay: -1
        )

        // when

        interactor.setup()

        let showPincodeExpectation = XCTestExpectation()

        stub(wireframe) { stub in
            when(stub.showSecuringOverlay()).thenDoNothing()

            when(stub.showAuthorization()).then {
                showPincodeExpectation.fulfill()
            }
        }

        applicationHandler.willResignActiveHandler(
            notification: Notification(name: UIApplication.willResignActiveNotification)
        )

        applicationHandler.willEnterForegroundHandler(
            notification: Notification(name: UIApplication.willEnterForegroundNotification)
        )

        // then

        wait(for: [showPincodeExpectation], timeout: 1)
    }

    func testRequestExecutesIfNoPincode() throws {
        // given

        let wireframe = MockSecurityLayerWireframeProtocol()
        let presenter = SecurityLayerPresenter(wireframe: wireframe)

        let applicationHandler = SecuredApplicationHandlerProxy()

        let interactor = SecurityLayerInteractor(
            presenter: presenter,
            applicationHandler: applicationHandler,
            keystore: InMemoryKeychain(),
            inactivityDelay: TimeInterval.greatestFiniteMagnitude
        )

        let securityLayer = SecurityLayerService(
            interactor: interactor,
            wireframe: wireframe,
            applicationHandlingProxy: applicationHandler
        )

        // when

        stub(wireframe) { stub in
            when(stub.isAuthorizing.get).thenReturn(false)
        }

        interactor.setup()

        let executionExpectation = XCTestExpectation()

        securityLayer.scheduleExecutionIfAuthorized {
            executionExpectation.fulfill()
        }

        // then

        wait(for: [executionExpectation], timeout: 1)

        XCTAssertTrue(securityLayer.scheduledRequests.isEmpty)
    }

    func testRequestExecutesIfAuthorized() {
        // given

        let wireframe = MockSecurityLayerWireframeProtocol()
        let presenter = SecurityLayerPresenter(wireframe: wireframe)

        let applicationHandler = SecuredApplicationHandlerProxy()

        let interactor = SecurityLayerInteractor(
            presenter: presenter,
            applicationHandler: applicationHandler,
            keystore: InMemoryKeychain(),
            inactivityDelay: -1
        )

        let securityLayer = SecurityLayerService(
            interactor: interactor,
            wireframe: wireframe,
            applicationHandlingProxy: applicationHandler
        )

        // when

        interactor.setup()

        stub(wireframe) { stub in
            when(stub.isAuthorizing.get).thenReturn(true)
        }

        interactor.setup()

        let executionExpectation = XCTestExpectation()

        securityLayer.scheduleExecutionIfAuthorized {
            executionExpectation.fulfill()
        }

        // then

        XCTAssertEqual(securityLayer.scheduledRequests.count, 1)

        // when

        securityLayer.executeScheduledRequests(true)

        wait(for: [executionExpectation], timeout: 1)

        XCTAssertTrue(securityLayer.scheduledRequests.isEmpty)
    }

    func testRequestsRejectedIfGoingBackgroundWithoutAuth() {
        // given

        let wireframe = MockSecurityLayerWireframeProtocol()
        let presenter = SecurityLayerPresenter(wireframe: wireframe)

        let applicationHandler = SecuredApplicationHandlerProxy()

        let interactor = SecurityLayerInteractor(
            presenter: presenter,
            applicationHandler: applicationHandler,
            keystore: InMemoryKeychain(),
            inactivityDelay: -1
        )

        let securityLayer = SecurityLayerService(
            interactor: interactor,
            wireframe: wireframe,
            applicationHandlingProxy: applicationHandler
        )

        interactor.service = securityLayer

        // when

        stub(wireframe) { stub in
            when(stub.isAuthorizing.get).thenReturn(true)
        }

        interactor.setup()

        securityLayer.scheduleExecutionIfAuthorized {}

        // then

        XCTAssertEqual(securityLayer.scheduledRequests.count, 1)

        // when

        applicationHandler.didEnterBackgroundHandler(
            notification: Notification(name: UIApplication.didEnterBackgroundNotification)
        )

        XCTAssertTrue(securityLayer.scheduledRequests.isEmpty)
    }
}
