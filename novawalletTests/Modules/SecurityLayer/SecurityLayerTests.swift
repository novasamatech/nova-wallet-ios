import XCTest
@testable import novawallet
import SoraKeystore
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
            when(stub).showSecuringOverlay().then {
                showOverlayExpectation.fulfill()
            }
        }

        NotificationCenter.default.post(name: UIApplication.willResignActiveNotification, object: nil)

        // then

        wait(for: [showOverlayExpectation], timeout: 1)

        // when

        let hideOverlayExpectation = XCTestExpectation()

        stub(wireframe) { stub in
            when(stub).hideSecuringOverlay().then {
                hideOverlayExpectation.fulfill()
            }
        }

        NotificationCenter.default.post(name: UIApplication.didBecomeActiveNotification, object: nil)

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
            when(stub).showSecuringOverlay().thenDoNothing()

            when(stub).showAuthorization().then {
                showPincodeExpectation.fulfill()
            }
        }

        NotificationCenter.default.post(name: UIApplication.willResignActiveNotification, object: nil)

        NotificationCenter.default.post(name: UIApplication.willEnterForegroundNotification, object: nil)

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
            when(stub).isAuthorizing.get.thenReturn(false)
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
            when(stub).isAuthorizing.get.thenReturn(true)
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
            when(stub).isAuthorizing.get.thenReturn(true)
        }

        interactor.setup()

        securityLayer.scheduleExecutionIfAuthorized {}

        // then

        XCTAssertEqual(securityLayer.scheduledRequests.count, 1)

        // when

        NotificationCenter.default.post(name: UIApplication.didEnterBackgroundNotification, object: nil)

        XCTAssertTrue(securityLayer.scheduledRequests.isEmpty)
    }
}
