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
        if name == Constants.messageHandlerName {
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
        let subscriptionScript = createAppAttestSubscriptionScript()

        return DAppTransportModel(
            name: Constants.messageHandlerName,
            handlerNames: [Constants.messageHandlerName],
            scripts: [subscriptionScript]
        )
    }

    func createAppAttestSubscriptionScript() -> DAppBrowserScript {
        let content =
            """
            window.addEventListener("message", ({ data, source }) => {
                if (source !== window) {
                    return;
                }

                if (data.origin === "\(Constants.jsInterfaceName)") {
                    window.webkit.messageHandlers.\(Constants.messageHandlerName).postMessage(data);
                }
            });
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
                do {
                    let response = try dAppCallFactory.createDAppResponse()
                    self?.presenter?.didReceive(response: response)
                } catch {
                    self?.logger?.error("Failed to generate DAapp response: \(error)")
                }
            case let .failure(error):
                self?.logger?.error("Failed to process app attest request: \(error)")
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
}

// MARK: - Constants

private extension DAppBrowserAppAttestInteractor {
    enum Constants {
        static let jsInterfaceName = "IntegrityProvider"
        static let messageHandlerName = "appAttestHandler"
    }
}
