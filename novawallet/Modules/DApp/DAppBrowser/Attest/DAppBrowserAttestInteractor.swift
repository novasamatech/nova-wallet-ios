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
            handleAppAttestMessage(message, host: host)
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

    func handleAppAttestMessage(_ message: Any, host: String) {
        guard let parsedMessage = parseAppAttestMessage(message) else {
            logger?.error("Failed to parse app attest message")
            return
        }

        logger?.debug("Received app attest message: \(parsedMessage.messageType.rawValue)")

        switch parsedMessage.messageType {
        case .requestIntegrityCheck:
            handleIntegrityCheckRequest(message: parsedMessage, host: host)
        }
    }

    func parseAppAttestMessage(_ message: Any) -> AppAttestMessage? {
        guard
            let dict = message as? NSDictionary,
            let parsedMessage = try? dict.map(to: AppAttestMessage.self)
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
