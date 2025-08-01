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
        if name == Constants.jsInterfaceName {
            handleIntegrityCheckMessage(message)
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
            name: Constants.jsInterfaceName,
            handlerNames: [Constants.jsInterfaceName],
            scripts: [subscriptionScript]
        )
    }

    func createAppAttestSubscriptionScript() -> DAppBrowserScript {
        let content = """
        window.addEventListener("message", ({ data, source }) => {
            if (source !== window) {
                return;
            }

            window.webkit.messageHandlers.\(Constants.jsInterfaceName).postMessage(data);
        });
        """

        return DAppBrowserScript(content: content, insertionPoint: .atDocStart)
    }

    func handleIntegrityCheckMessage(_ message: Any) {
        guard let parsedMessage = parseIntegrityCheckMessage(message) else {
            logger?.error("Failed to parse app attest request")
            return
        }

        logger?.debug("Received app attest request for URL: \(parsedMessage.baseURL)")

        let wrapper = attestationProvider.createAttestWrapper(
            for: parsedMessage.baseURL,
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

    func parseIntegrityCheckMessage(_ message: Any) -> IntegrityCheckMessage? {
        guard
            let dict = message as? NSDictionary,
            let parsedMessage = try? dict.map(to: IntegrityCheckMessage.self)
        else {
            return nil
        }

        return parsedMessage
    }
}

// MARK: - Constants

private extension DAppBrowserAppAttestInteractor {
    enum Constants {
        static let jsInterfaceName = "IntegrityProvider"
    }
}
