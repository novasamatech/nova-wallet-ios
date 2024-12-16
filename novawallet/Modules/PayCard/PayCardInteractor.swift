import Foundation
import SoraKeystore

final class PayCardInteractor {
    weak var presenter: PayCardInteractorOutputProtocol?

    let payCardHookFactory: PayCardHookFactoryProtocol
    let payCardResourceProvider: PayCardResourceProviding
    let operationQueue: OperationQueue
    let pendingTimeout: TimeInterval
    let logger: LoggerProtocol

    private let settingsManager: SettingsManagerProtocol
    private var messageHandlers: [PayCardMessageHandling] = []

    init(
        payCardHookFactory: PayCardHookFactoryProtocol,
        payCardResourceProvider: PayCardResourceProviding,
        settingsManager: SettingsManagerProtocol,
        operationQueue: OperationQueue,
        pendingTimeout: TimeInterval,
        logger: LoggerProtocol
    ) {
        self.payCardHookFactory = payCardHookFactory
        self.payCardResourceProvider = payCardResourceProvider
        self.settingsManager = settingsManager
        self.operationQueue = operationQueue
        self.pendingTimeout = pendingTimeout
        self.logger = logger
    }

    private func provideModel(for resource: PayCardHtmlResource, hooks: [PayCardHook]) {
        let messageNames = hooks.reduce(Set<String>()) { $0.union($1.messageNames) }
        let scripts = hooks.map(\.script)

        let model = PayCardModel(
            resource: resource,
            messageNames: messageNames,
            scripts: scripts
        )

        presenter?.didReceive(model: model)
    }
}

// MARK: PayCardInteractorInputProtocol

extension PayCardInteractor: PayCardInteractorInputProtocol {
    func setup() {
        let resourceWrapper = payCardResourceProvider.loadResourceWrapper()

        let hooks = payCardHookFactory.createHooks(for: self)

        execute(
            wrapper: resourceWrapper,
            inOperationQueue: operationQueue,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case let .success(resource):
                self?.messageHandlers = hooks.flatMap(\.handlers)
                self?.provideModel(for: resource, hooks: hooks)
            case let .failure(error):
                self?.logger.error("Unexpected hooks \(error)")
            }
        }
    }

    func checkPendingTimeout() {
        guard let cardOpenTimestamp = settingsManager.novaCardOpenTimestamp else {
            return
        }

        let currentTimestamp = Date().timeIntervalSince1970
        let elapsedTime = currentTimestamp - TimeInterval(cardOpenTimestamp)

        if elapsedTime < pendingTimeout {
            presenter?.didReceiveCardStatus(
                .pending(
                    remained: pendingTimeout - elapsedTime,
                    total: pendingTimeout
                )
            )
        } else {
            presenter?.didReceiveCardStatus(.failed)
        }
    }

    func processIssueInit() {
        let timestamp = Date().timeIntervalSince1970
        settingsManager.novaCardOpenTimestamp = UInt64(timestamp)

        checkPendingTimeout()
    }

    func processMessage(body: Any, of name: String) {
        logger.debug("New message \(name): \(body)")

        guard let handler = messageHandlers.first(where: { $0.canHandleMessageOf(name: name) }) else {
            logger.warning("No handler registered to process \(name)")
            return
        }

        handler.handle(message: body, of: name)
    }
}

// MARK: PayCardHookDelegate

extension PayCardInteractor: PayCardHookDelegate {
    func didRequestTopup(from model: PayCardTopupModel) {
        presenter?.didRequestTopup(for: model)
    }

    func didReceiveNoCard() {
        checkPendingTimeout()
    }

    func didOpenCard() {
        let createdStatus = PayCardStatus.created

        settingsManager.novaCardOpenTimestamp = nil

        presenter?.didReceiveCardStatus(createdStatus)
    }

    func didFailToOpenCard() {
        let failedStatus = PayCardStatus.failed

        settingsManager.novaCardOpenTimestamp = nil

        presenter?.didReceiveCardStatus(failedStatus)
    }
}
