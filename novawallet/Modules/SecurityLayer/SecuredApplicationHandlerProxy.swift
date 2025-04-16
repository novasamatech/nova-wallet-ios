import Foundation
import Foundation_iOS

protocol SecuredApplicationHandlerProxyProtocol: AnyObject {
    func addApplicationHandler() -> ApplicationHandlerProtocol
}

final class SecuredApplicationHandlerProxy: ApplicationHandlerProtocol {
    private(set) var applicationHandlers: [WeakWrapper] = []

    weak var securedLayer: SecurityLayerServiceProtocol?

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    weak var delegate: ApplicationHandlerDelegate?

    init() {
        setupNotificationHandlers()
    }

    // MARK: Observation

    private func setupNotificationHandlers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(willResignActiveHandler(notification:)),
            name: UIApplication.willResignActiveNotification,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(didBecomeActiveHandler(notification:)),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(willEnterForegroundHandler(notification:)),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(didEnterBackgroundHandler(notification:)),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
    }

    private func callApplicationHadlersOnAuthorized(
        for isAuthorized: Bool,
        closure: (ApplicationHandlerProtocol) -> Void
    ) {
        guard isAuthorized else {
            return
        }

        applicationHandlers.forEach { wrapper in
            guard let handler = wrapper.target as? ApplicationHandlerProtocol else {
                return
            }

            closure(handler)
        }
    }

    // MARK: Handlers

    @objc func willResignActiveHandler(notification: Notification) {
        delegate?.didReceiveWillResignActive?(notification: notification)

        securedLayer?.scheduleExecution { [weak self] isAuthorized in
            self?.callApplicationHadlersOnAuthorized(for: isAuthorized) { handler in
                handler.delegate?.didReceiveWillResignActive?(notification: notification)
            }
        }
    }

    @objc func didBecomeActiveHandler(notification: Notification) {
        delegate?.didReceiveDidBecomeActive?(notification: notification)

        securedLayer?.scheduleExecution { [weak self] isAuthorized in
            self?.callApplicationHadlersOnAuthorized(for: isAuthorized) { handler in
                handler.delegate?.didReceiveDidBecomeActive?(notification: notification)
            }
        }
    }

    @objc func willEnterForegroundHandler(notification: Notification) {
        delegate?.didReceiveWillEnterForeground?(notification: notification)

        securedLayer?.scheduleExecution { [weak self] isAuthorized in
            self?.callApplicationHadlersOnAuthorized(for: isAuthorized) { handler in
                handler.delegate?.didReceiveWillEnterForeground?(notification: notification)
            }
        }
    }

    @objc func didEnterBackgroundHandler(notification: Notification) {
        delegate?.didReceiveDidEnterBackground?(notification: notification)

        securedLayer?.scheduleExecution { [weak self] isAuthorized in
            self?.callApplicationHadlersOnAuthorized(for: isAuthorized) { handler in
                handler.delegate?.didReceiveDidEnterBackground?(notification: notification)
            }
        }
    }
}

extension SecuredApplicationHandlerProxy: SecuredApplicationHandlerProxyProtocol {
    func addApplicationHandler() -> ApplicationHandlerProtocol {
        let applicationHandler = SecuredApplicationHandlerProxyItem()

        applicationHandlers.clearEmptyItems()
        applicationHandlers.append(WeakWrapper(target: applicationHandler))

        return applicationHandler
    }
}

final class SecuredApplicationHandlerProxyItem: ApplicationHandlerProtocol {
    weak var delegate: ApplicationHandlerDelegate?
}
