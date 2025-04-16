import Foundation
import Keystore_iOS

final class PayCardInteractor {
    weak var presenter: PayCardInteractorOutputProtocol?

    let paramsProvider: MercuryoCardParamsProviderProtocol
    let payCardHookFactory: PayCardHookFactoryProtocol
    let payCardResourceProvider: PayCardResourceProviding
    let operationQueue: OperationQueue
    let pendingTimeout: TimeInterval
    let logger: LoggerProtocol

    private let settingsManager: SettingsManagerProtocol
    private var messageHandlers: [PayCardMessageHandling] = []

    init(
        paramsProvider: MercuryoCardParamsProviderProtocol,
        payCardHookFactory: PayCardHookFactoryProtocol,
        payCardResourceProvider: PayCardResourceProviding,
        settingsManager: SettingsManagerProtocol,
        operationQueue: OperationQueue,
        pendingTimeout: TimeInterval,
        logger: LoggerProtocol
    ) {
        self.paramsProvider = paramsProvider
        self.payCardHookFactory = payCardHookFactory
        self.payCardResourceProvider = payCardResourceProvider
        self.settingsManager = settingsManager
        self.operationQueue = operationQueue
        self.pendingTimeout = pendingTimeout
        self.logger = logger
    }

    private func provideModel(
        for resource: PayCardResource,
        hooks: [PayCardHook]
    ) {
        let messageNames = hooks.reduce(Set<String>()) { $0.union($1.messageNames) }
        let scripts = hooks.map(\.script)

        let model = PayCardModel(
            resource: resource,
            messageNames: messageNames,
            scripts: scripts.compactMap { $0 }
        )

        presenter?.didReceive(model: model)
    }
}

// MARK: PayCardInteractorInputProtocol

extension PayCardInteractor: PayCardInteractorInputProtocol {
    func setup() {
        let fetchParamsWrapper = paramsProvider.fetchParamsWrapper()

        execute(
            wrapper: fetchParamsWrapper,
            inOperationQueue: operationQueue,
            runningCallbackIn: .main
        ) { [weak self] result in
            guard let self else { return }

            do {
                switch result {
                case let .success(params):
                    let resource = try payCardResourceProvider.loadResource(using: params)
                    let hooks = payCardHookFactory.createHooks(using: params, for: self)
                    messageHandlers = hooks.flatMap(\.handlers)
                    provideModel(for: resource, hooks: hooks)
                case let .failure(error):
                    logger.error("Unexpected hooks \(error)")
                }
            } catch {
                logger.error("Resource unavailable \(error)")
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
            presenter?.didReceivePayStatus(
                .pending(
                    remained: pendingTimeout - elapsedTime,
                    total: pendingTimeout
                )
            )
        } else {
            presenter?.didReceivePayStatus(.failed)
        }
    }

    func processFundInit() {
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
        let createdStatus = PayCardStatus.completed

        settingsManager.novaCardOpenTimestamp = nil

        presenter?.didReceivePayStatus(createdStatus)
    }

    func didFailToOpenCard() {
        let failedStatus = PayCardStatus.failed

        settingsManager.novaCardOpenTimestamp = nil

        presenter?.didReceivePayStatus(failedStatus)
    }

    func didReceivePendingCardOpen() {
        if settingsManager.novaCardOpenTimestamp != nil {
            checkPendingTimeout()
        } else {
            processFundInit()
        }
    }
}
