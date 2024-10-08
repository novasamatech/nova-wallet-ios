import Foundation
import SoraKeystore

final class PayCardInteractor {
    weak var presenter: PayCardInteractorOutputProtocol?

    let payCardHookFactory: PayCardHookFactoryProtocol
    let payCardResourceProvider: PayCardResourceProviding
    let operationQueue: OperationQueue
    let logger: LoggerProtocol

    private let settingsManager: SettingsManagerProtocol
    private var messageHandlers: [PayCardMessageHandling] = []

    init(
        payCardHookFactory: PayCardHookFactoryProtocol,
        payCardResourceProvider: PayCardResourceProviding,
        settingsManager: SettingsManagerProtocol,
        operationQueue: OperationQueue,
        logger: LoggerProtocol
    ) {
        self.payCardHookFactory = payCardHookFactory
        self.payCardResourceProvider = payCardResourceProvider
        self.settingsManager = settingsManager
        self.operationQueue = operationQueue
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

extension PayCardInteractor: PayCardInteractorInputProtocol {
    func setup() {
        if let cardOpenStartTimestamp = settingsManager.novaCardOpenTimeStamp {
            presenter?.didReceiveCardOpenTimestamp(cardOpenStartTimestamp.timeInterval)
        }

        if let cardStatus = settingsManager.novaCardStatus {
            presenter?.didReceiveCardStatus(cardStatus)
        }

        do {
            let resource = try payCardResourceProvider.loadResource()

            let hooksWrapper = payCardHookFactory.createHooks(for: self)

            execute(
                wrapper: hooksWrapper,
                inOperationQueue: operationQueue,
                runningCallbackIn: .main
            ) { [weak self] result in
                switch result {
                case let .success(hooks):
                    self?.messageHandlers = hooks.flatMap(\.handlers)
                    self?.provideModel(for: resource, hooks: hooks)
                case let .failure(error):
                    self?.logger.error("Unexpected hooks \(error)")
                }
            }
        } catch {
            logger.error("Unexpected \(error)")
        }
    }

    func processSuccessTopup() {
        guard settingsManager.novaCardStatus != .created else {
            return
        }

        let pendingStatus = PayCardStatus.pending

        settingsManager.novaCardOpenTimeStamp = UInt64(Date().timeIntervalSince1970)
        settingsManager.novaCardStatus = pendingStatus

        presenter?.didReceiveCardStatus(pendingStatus)
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

extension PayCardInteractor: PayCardHookDelegate {
    func didRequestTopup(from model: PayCardTopupModel) {
        presenter?.didRequestTopup(for: model)
    }

    func didOpenCard() {
        let createdStatus = PayCardStatus.created

        settingsManager.novaCardStatus = createdStatus

        presenter?.didReceiveCardStatus(createdStatus)
    }

    func didFailToOpenCard() {
        let failedStatus = PayCardStatus.failed

        settingsManager.novaCardStatus = failedStatus

        presenter?.didReceiveCardStatus(failedStatus)
    }
}
