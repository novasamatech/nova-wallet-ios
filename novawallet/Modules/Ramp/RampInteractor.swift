import UIKit

final class RampInteractor {
    weak var presenter: RampInteractorOutputProtocol!

    let wallet: MetaAccountModel
    let chainAsset: ChainAsset

    let rampProvider: RampProviderProtocol
    let logger: LoggerProtocol

    let eventCenter: EventCenterProtocol
    let action: RampAction

    let operationQueue: OperationQueue

    private var messageHandlers: [PayCardMessageHandling] = []
    private var callStore = CancellableCallStore()

    init(
        wallet: MetaAccountModel,
        chainAsset: ChainAsset,
        rampProvider: RampProviderProtocol,
        eventCenter: EventCenterProtocol,
        action: RampAction,
        operationQueue: OperationQueue,
        logger: LoggerProtocol
    ) {
        self.wallet = wallet
        self.chainAsset = chainAsset
        self.rampProvider = rampProvider
        self.eventCenter = eventCenter
        self.action = action
        self.operationQueue = operationQueue
        self.logger = logger
    }

    deinit {
        callStore.cancel()
    }
}

// MARK: Private

private extension RampInteractor {
    func provideModel(with hooks: [PayCardHook]) {
        guard !callStore.hasCall else {
            return
        }

        let messageNames = hooks.reduce(Set<String>()) { $0.union($1.messageNames) }
        let scripts = hooks.map(\.script)

        let urlWrapper = action.urlFactory.createURLWrapper()

        executeCancellable(
            wrapper: urlWrapper,
            inOperationQueue: operationQueue,
            backingCallIn: callStore,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case let .success(url):
                let model = RampModel(
                    resource: .init(url: url),
                    messageNames: messageNames,
                    scripts: scripts.compactMap { $0 }
                )
                let urlString = url.absoluteString
                self?.presenter?.didReceive(model: model)
            case let .failure(error):
                self?.logger.error("Failed to create ramp provider URL: \(error)")
            }
        }
    }

    func createHooks() -> [RampHook] {
        guard
            let account = wallet.fetch(for: chainAsset.chain.accountRequest()),
            let address = try? account.accountId.toAddress(using: chainAsset.chain.chainFormat)
        else {
            return []
        }

        let params = OffRampHookParams(
            chainAsset: chainAsset,
            refundAddress: address
        )

        return rampProvider.buildRampHooks(
            for: action,
            using: params,
            for: self
        )
    }
}

// MARK: RampInteractorInputProtocol

extension RampInteractor: RampInteractorInputProtocol {
    func processMessage(
        body: Any,
        of name: String
    ) {
        logger.debug("New message \(name): \(body)")

        guard let handler = messageHandlers.first(where: { $0.canHandleMessageOf(name: name) }) else {
            logger.warning("No handler registered to process \(name)")
            return
        }

        handler.handle(message: body, of: name)
    }

    func setup() {
        let hooks = createHooks()

        messageHandlers = hooks.flatMap(\.handlers)
        provideModel(with: hooks)

        eventCenter.add(observer: self, dispatchIn: .main)
    }
}

// MARK: RampHookDelegate

extension RampInteractor: RampHookDelegate {
    func didRequestTransfer(from model: OffRampTransferModel) {
        presenter?.didRequestTransfer(for: model)
    }

    func didFinishOperation() {
        presenter.didCompleteOperation(action: action)
    }
}

// MARK: EventVisitorProtocol

extension RampInteractor: EventVisitorProtocol {
    func processPurchaseCompletion(event _: PurchaseCompleted) {
        presenter.didCompleteOperation(action: action)
    }
}
