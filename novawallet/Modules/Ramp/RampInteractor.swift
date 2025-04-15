import UIKit

final class RampInteractor {
    weak var presenter: RampInteractorOutputProtocol!

    let wallet: MetaAccountModel
    let chainAsset: ChainAsset

    let rampProvider: RampProviderProtocol
    let logger: LoggerProtocol

    let eventCenter: EventCenterProtocol
    let action: RampAction

    private var messageHandlers: [PayCardMessageHandling] = []

    init(
        wallet: MetaAccountModel,
        chainAsset: ChainAsset,
        rampProvider: RampProviderProtocol,
        eventCenter: EventCenterProtocol,
        action: RampAction,
        logger: LoggerProtocol
    ) {
        self.wallet = wallet
        self.chainAsset = chainAsset
        self.rampProvider = rampProvider
        self.eventCenter = eventCenter
        self.action = action
        self.logger = logger
    }
}

// MARK: Private

private extension RampInteractor {
    func provideModel(with hooks: [PayCardHook]) {
        let messageNames = hooks.reduce(Set<String>()) { $0.union($1.messageNames) }
        let scripts = hooks.map(\.script)

        let model = RampModel(
            resource: .init(url: action.url),
            messageNames: messageNames,
            scripts: scripts.compactMap { $0 }
        )

        presenter?.didReceive(model: model)
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
