import Foundation

final class PayCardInteractor {
    weak var presenter: PayCardInteractorOutputProtocol?

    let payCardModelFactory: PayCardHookFactoryProtocol
    let payCardResourceProvider: PayCardResourceProviding
    let operationQueue: OperationQueue
    let logger: LoggerProtocol

    private var messageHandlers: [PayCardMessageHandling] = []

    init(
        payCardModelFactory: PayCardHookFactoryProtocol,
        payCardResourceProvider: PayCardResourceProviding,
        operationQueue: OperationQueue,
        logger: LoggerProtocol
    ) {
        self.payCardModelFactory = payCardModelFactory
        self.payCardResourceProvider = payCardResourceProvider
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
        do {
            let resource = try payCardResourceProvider.loadResource()

            let hooksWrapper = payCardModelFactory.createHooks(for: self)

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

    func didOpenCard() {}

    func didFailToOpenCard() {}
}
