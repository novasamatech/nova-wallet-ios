import Foundation
import RobinHood

final class DAppInteractionMediator {
    struct QueueMessage {
        let host: String?
        let transportName: String
        let underliningMessage: Any
    }

    let presenter: DAppInteractionOutputProtocol

    let chainsStore: ChainsStoreProtocol
    let settingsRepository: AnyDataProviderRepository<DAppSettings>
    let securedLayer: SecurityLayerServiceProtocol
    let sequentialPhishingVerifier: PhishingSiteVerifing
    let operationQueue: OperationQueue
    let logger: LoggerProtocol?

    private(set) var messageQueue: [QueueMessage] = []
    private(set) var transports: [DAppTransportProtocol] = []

    let children: [DAppInteractionChildProtocol]

    init(
        presenter: DAppInteractionOutputProtocol,
        children: [DAppInteractionChildProtocol],
        chainsStore: ChainsStoreProtocol,
        settingsRepository: AnyDataProviderRepository<DAppSettings>,
        securedLayer: SecurityLayerServiceProtocol,
        sequentialPhishingVerifier: PhishingSiteVerifing,
        operationQueue: OperationQueue,
        logger: LoggerProtocol?
    ) {
        self.presenter = presenter
        self.children = children
        self.chainsStore = chainsStore
        self.settingsRepository = settingsRepository
        self.securedLayer = securedLayer
        self.sequentialPhishingVerifier = sequentialPhishingVerifier
        self.operationQueue = operationQueue
        self.logger = logger
    }

    private func processMessageIfNeeded() {
        guard transports.allSatisfy({ $0.isIdle() }), let queueMessage = messageQueue.first else {
            logger?.debug("Some of the transports busy and can't process messages: \(messageQueue.count)")
            return
        }

        messageQueue.removeFirst()

        let transport = transports.first { $0.name == queueMessage.transportName }

        transport?.process(message: queueMessage.underliningMessage, host: queueMessage.host)
    }

    private func bringPhishingDetectedStateAndNotify(for host: String) {
        let allNotPhishing = transports
            .map { $0.bringPhishingDetectedStateIfNeeded() }
            .allSatisfy { !$0 }

        if !allNotPhishing {
            presenter.didDetectPhishing(host: host)
        }
    }

    private func verifyPhishing(for host: String?, completion: ((Bool) -> Void)?) {
        guard let host = host else {
            completion?(true)
            return
        }

        sequentialPhishingVerifier.verify(host: host) { [weak self] result in
            switch result {
            case let .success(isNotPhishing):
                if !isNotPhishing {
                    self?.bringPhishingDetectedStateAndNotify(for: host)
                }

                completion?(isNotPhishing)
            case let .failure(error):
                self?.presenter.didReceive(error: .phishingVerifierFailed(error))
            }
        }
    }
}

extension DAppInteractionMediator: DAppInteractionMediating {
    func register(transport: DAppTransportProtocol) {
        guard !transports.contains(where: { $0 !== transport }) else {
            return
        }

        transports.append(transport)

        transport.start()
    }

    func unregister(transport: DAppTransportProtocol) {
        transports = transports.filter { $0 !== transport }

        transport.stop()
    }

    func process(message: Any, host: String?, transport name: String) {
        securedLayer.scheduleExecutionIfAuthorized { [weak self] in
            self?.logger?.debug("Did receive \(name) message from \(host ?? ""): \(message)")

            self?.verifyPhishing(for: host) { [weak self] isNotPhishing in
                if isNotPhishing {
                    let queueMessage = QueueMessage(
                        host: host,
                        transportName: name,
                        underliningMessage: message
                    )
                    self?.messageQueue.append(queueMessage)

                    self?.processMessageIfNeeded()
                }
            }
        }
    }

    func process(authRequest: DAppAuthRequest) {
        securedLayer.scheduleExecutionIfAuthorized { [weak self] in
            self?.presenter.didReceiveAuth(request: authRequest)
        }
    }

    func process(signingRequest: DAppOperationRequest, type: DAppSigningType) {
        securedLayer.scheduleExecutionIfAuthorized { [weak self] in
            self?.presenter.didReceiveConfirmation(request: signingRequest, type: type)
        }
    }

    func processMessageQueue() {
        securedLayer.scheduleExecutionIfAuthorized { [weak self] in
            self?.processMessageIfNeeded()
        }
    }
}

extension DAppInteractionMediator: DAppInteractionInputProtocol {
    func processConfirmation(response: DAppOperationResponse, forTransport name: String) {
        securedLayer.scheduleExecutionIfAuthorized { [weak self] in
            self?.transports.first(where: { $0.name == name })?.processConfirmation(response: response)
        }
    }

    func processAuth(response: DAppAuthResponse, forTransport name: String) {
        securedLayer.scheduleExecutionIfAuthorized { [weak self] in
            self?.transports.first(where: { $0.name == name })?.processAuth(response: response)
        }
    }
}

extension DAppInteractionMediator: ChainsStoreDelegate {
    func didUpdateChainsStore(_ chainsStore: ChainsStoreProtocol) {
        logger?.debug("Did update chain store: \(chainsStore.availableChainIds().count)")

        transports.forEach { $0.processChainsChanges() }
    }
}

extension DAppInteractionMediator {
    func setup() {
        chainsStore.delegate = self
        chainsStore.setup()

        children.forEach { $0.setup() }
    }

    func throttle() {
        children.forEach { $0.throttle() }
    }
}
