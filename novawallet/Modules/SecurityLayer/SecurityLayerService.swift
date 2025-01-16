import Foundation
import Keystore_iOS
import Foundation_iOS

typealias SecurityAuthorizationCompletion = (Bool) -> Void

protocol SecurityLayerServiceProtocol: AnyObject {
    var interactor: SecurityLayerInteractorInputProtocol { get }
    var applicationHandlingProxy: SecuredApplicationHandlerProxyProtocol { get }

    func scheduleExecution(closure: @escaping SecurityAuthorizationCompletion)
}

extension SecurityLayerServiceProtocol {
    func scheduleExecutionIfAuthorized(_ closure: @escaping () -> Void) {
        scheduleExecution { isAuthorized in
            if isAuthorized {
                closure()
            }
        }
    }
}

protocol SecurityLayerExecutionProtocol: AnyObject {
    func executeScheduledRequests(_ isAuthorized: Bool)
}

final class SecurityLayerService {
    static let inactivityTimeoutInMinutes: TimeInterval = 5.0

    static let shared: SecurityLayerService = {
        let wireframe = SecurityLayerWireframe()
        let presenter = SecurityLayerPresenter(wireframe: wireframe)

        let applicationHandlingProxy = SecuredApplicationHandlerProxy()

        let interactor = SecurityLayerInteractor(
            presenter: presenter,
            applicationHandler: applicationHandlingProxy,
            keystore: Keychain(),
            inactivityDelay: inactivityTimeoutInMinutes.secondsFromMinutes
        )

        presenter.interactor = interactor

        let service = SecurityLayerService(
            interactor: interactor,
            wireframe: wireframe,
            applicationHandlingProxy: applicationHandlingProxy
        )

        wireframe.authorizationCompletionHandler = service
        applicationHandlingProxy.securedLayer = service

        return service
    }()

    let interactor: SecurityLayerInteractorInputProtocol
    let wireframe: SecurityLayerWireframeProtocol
    let applicationHandlingProxy: SecuredApplicationHandlerProxyProtocol

    private(set) var scheduledRequests: [SecurityAuthorizationCompletion] = []

    init(
        interactor: SecurityLayerInteractorInputProtocol,
        wireframe: SecurityLayerWireframeProtocol,
        applicationHandlingProxy: SecuredApplicationHandlerProxyProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.applicationHandlingProxy = applicationHandlingProxy
    }
}

extension SecurityLayerService: SecurityLayerServiceProtocol {
    func scheduleExecution(closure: @escaping SecurityAuthorizationCompletion) {
        if wireframe.isAuthorizing {
            scheduledRequests.append(closure)
        } else {
            closure(true)
        }
    }
}

extension SecurityLayerService: SecurityLayerExecutionProtocol {
    func executeScheduledRequests(_ isAuthorized: Bool) {
        let requests = scheduledRequests
        scheduledRequests = []

        requests.forEach { closure in
            closure(isAuthorized)
        }
    }
}
