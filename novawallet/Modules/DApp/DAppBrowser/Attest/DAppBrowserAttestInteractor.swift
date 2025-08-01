import Foundation
import Operation_iOS
import Foundation_iOS
import SubstrateSdk
import DeviceCheck

final class DAppBrowserAppAttestInteractor: DAppBrowserInteractor {
    private let attestationProvider: DAppAttestationProviderProtocol

    init(
        transports: [DAppBrowserTransportProtocol],
        selectedTab: DAppBrowserTab,
        wallet: MetaAccountModel,
        chainRegistry: ChainRegistryProtocol,
        securedLayer: SecurityLayerServiceProtocol,
        dAppSettingsRepository: AnyDataProviderRepository<DAppSettings>,
        dAppGlobalSettingsRepository: AnyDataProviderRepository<DAppGlobalSettings>,
        dAppsLocalSubscriptionFactory: DAppLocalSubscriptionFactoryProtocol,
        dAppsFavoriteRepository: AnyDataProviderRepository<DAppFavorite>,
        operationQueue: OperationQueue,
        sequentialPhishingVerifier: PhishingSiteVerifing,
        tabManager: DAppBrowserTabManagerProtocol,
        applicationHandler: ApplicationHandlerProtocol,
        attestationProvider: DAppAttestationProviderProtocol,
        logger: LoggerProtocol? = nil
    ) {
        self.attestationProvider = attestationProvider

        super.init(
            transports: transports,
            selectedTab: selectedTab,
            wallet: wallet,
            chainRegistry: chainRegistry,
            securedLayer: securedLayer,
            dAppSettingsRepository: dAppSettingsRepository,
            dAppGlobalSettingsRepository: dAppGlobalSettingsRepository,
            dAppsLocalSubscriptionFactory: dAppsLocalSubscriptionFactory,
            dAppsFavoriteRepository: dAppsFavoriteRepository,
            operationQueue: operationQueue,
            sequentialPhishingVerifier: sequentialPhishingVerifier,
            tabManager: tabManager,
            applicationHandler: applicationHandler,
            logger: logger
        )
    }

    override func process(
        message: Any,
        host: String,
        transport name: String
    ) {
        if name == Constants.integrityCheckHandler || name == Constants.signatureVerificationErrorHandler {
            handleIntegrityProviderMessage(message)
            return
        }

        super.process(message: message, host: host, transport: name)
    }

    override func createTransportWrappers() -> [CompoundOperationWrapper<DAppTransportModel>] {
        var wrappers = super.createTransportWrappers()

        let appAttestWrapper = createAppAttestTransport()
        wrappers.append(.createWithResult(appAttestWrapper))

        return wrappers
    }
}

// MARK: - Private

private extension DAppBrowserAppAttestInteractor {
    func createAppAttestTransport() -> DAppTransportModel {
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

    func handleIntegrityProviderMessage(_ message: Any) {
        guard let parsedMessage = parseIntegrityProviderMessage(message) else {
            logger?.error("Failed to parse app attest request")
            return
        }

        switch parsedMessage {
        case let .integrityCheck(model):
            performAttestFlow(for: model.baseURL)
        case let .signatureVerificationError(model):
            logger?.error(model.error)
        }
    }

    func performAttestFlow(for url: String) {
        logger?.debug("Received app attest request for URL: \(url)")

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
                    self?.logger?.error("Failed to process app attest request: \(error)")
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
            logger?.error("Failed to generate DAapp response")
            return
        }

        presenter?.didReceive(response: response)
    }
}

// MARK: - Constants

private extension DAppBrowserAppAttestInteractor {
    enum Constants {
        static let jsInterfaceName = "IntegrityProvider"
        static let integrityCheckHandler = "requestIntegrityCheck"
        static let signatureVerificationErrorHandler = "signatureVerificationError"
    }
}
