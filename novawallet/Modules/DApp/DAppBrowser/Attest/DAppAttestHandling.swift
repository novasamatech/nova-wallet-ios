import UIKit
import Operation_iOS
import Foundation_iOS
import SubstrateSdk

protocol DAppAttestHandlerProtocol: AnyObject {
    var delegate: DAppAttestHandlerDelegate? { get set }

    func canHandle(transportName: String) -> Bool
    func handle(message: Any)
    func createTransportModel() -> DAppTransportModel
}

protocol DAppAttestHandlerDelegate: AnyObject {
    func handleResponse(_ response: DAppScriptResponse)
}

final class DAppAttestHandler {
    weak var delegate: DAppAttestHandlerDelegate?

    private let attestationProvider: DAppAttestationProviderProtocol
    private let operationQueue: OperationQueue
    private let logger: LoggerProtocol

    init(
        attestationProvider: DAppAttestationProviderProtocol,
        operationQueue: OperationQueue,
        logger: LoggerProtocol = Logger.shared
    ) {
        self.attestationProvider = attestationProvider
        self.operationQueue = operationQueue
        self.logger = logger
    }
}

// MARK: - Private

private extension DAppAttestHandler {
    func createBridgeScript() -> DAppBrowserScript {
        let content =
            """
                window.\(Constants.jsInterfaceName) = {
                    requestIntegrityCheck: function(baseURL) {
                        window.webkit.messageHandlers.\(Constants.integrityCheckHandler).postMessage({
                            baseURL: baseURL
                        });
                    },
                    signatureVerificationError: function(code, error) {
                        window.webkit.messageHandlers.\(Constants.signatureVerificationErrorHandler).postMessage({
                            code: code,
                            error: error
                        });
                    }
                };
            """

        return DAppBrowserScript(content: content, insertionPoint: .atDocStart)
    }

    func performAttestFlow(for url: String) {
        logger.debug("Received app attest request for URL: \(url)")

        let wrapper = attestationProvider.createAttestWrapper(
            for: url,
            with: { nil }
        )

        execute(
            wrapper: wrapper,
            inOperationQueue: operationQueue,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case let .success(dAppCallFactory):
                self?.sendDAppResponse(using: dAppCallFactory)
            case let .failure(error):
                guard
                    let attestError = error as? DAppAttestError,
                    case let .serverError(dAppCallFactory) = attestError
                else {
                    self?.logger.error("Failed to process app attest request: \(error)")
                    return
                }

                self?.sendDAppResponse(using: dAppCallFactory)
            }
        }
    }

    func parseIntegrityProviderMessage(_ message: Any) -> IntagrityProviderMessage? {
        guard let dict = message as? NSDictionary else {
            return nil
        }

        return if let parsedMessage = try? dict.map(to: IntegrityCheckMessage.self) {
            .integrityCheck(parsedMessage)
        } else if let parsedMessage = try? dict.map(to: IntegritySignatureVerificationError.self) {
            .signatureVerificationError(parsedMessage)
        } else {
            nil
        }
    }

    func sendDAppResponse(using factory: DAppAssertionCallFactory) {
        guard let response = try? factory.createDAppResponse() else {
            logger.error("Failed to generate DAapp response")
            return
        }

        delegate?.handleResponse(response)
    }
}

// MARK: - DAppAttestHandlerProtocol

extension DAppAttestHandler: DAppAttestHandlerProtocol {
    func canHandle(transportName: String) -> Bool {
        transportName == Constants.integrityCheckHandler ||
            transportName == Constants.signatureVerificationErrorHandler
    }

    func handle(message: Any) {
        guard let parsedMessage = parseIntegrityProviderMessage(message) else {
            logger.error("Failed to parse app attest request")
            return
        }

        switch parsedMessage {
        case let .integrityCheck(model):
            performAttestFlow(for: model.baseURL)
        case let .signatureVerificationError(model):
            logger.error(model.error)
        }
    }

    func createTransportModel() -> DAppTransportModel {
        let script = createBridgeScript()

        let handlerNames: Set<String> = [
            Constants.integrityCheckHandler,
            Constants.signatureVerificationErrorHandler,
            Constants.jsInterfaceName
        ]

        return DAppTransportModel(
            name: Constants.jsInterfaceName,
            handlerNames: handlerNames,
            scripts: [script]
        )
    }
}

// MARK: - Private types

private extension DAppAttestHandler {
    enum Constants {
        static let jsInterfaceName = "IntegrityProvider"
        static let integrityCheckHandler = "requestIntegrityCheck"
        static let signatureVerificationErrorHandler = "signatureVerificationError"
    }

    enum IntagrityProviderMessage {
        case integrityCheck(IntegrityCheckMessage)
        case signatureVerificationError(IntegritySignatureVerificationError)
    }
}
