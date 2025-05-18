import Foundation
import Keystore_iOS
import NovaCrypto
import Operation_iOS

final class RootInteractor {
    weak var presenter: RootInteractorOutputProtocol?

    let settings: SelectedWalletSettings
    let keystore: KeystoreProtocol
    let applicationConfig: ApplicationConfigProtocol
    let chainRegistryClosure: ChainRegistryLazyClosure
    let securityLayerInteractor: SecurityLayerInteractorInputProtocol
    let eventCenter: EventCenterProtocol
    let migrators: [Migrating]
    let logger: LoggerProtocol?

    init(
        settings: SelectedWalletSettings,
        keystore: KeystoreProtocol,
        applicationConfig: ApplicationConfigProtocol,
        securityLayerInteractor: SecurityLayerInteractorInputProtocol,
        chainRegistryClosure: @escaping ChainRegistryLazyClosure,
        eventCenter: EventCenterProtocol,
        migrators: [Migrating],
        logger: LoggerProtocol? = nil
    ) {
        self.settings = settings
        self.keystore = keystore
        self.applicationConfig = applicationConfig
        self.securityLayerInteractor = securityLayerInteractor
        self.chainRegistryClosure = chainRegistryClosure
        self.eventCenter = eventCenter
        self.migrators = migrators
        self.logger = logger
    }

    private func setupURLHandlingService() {
        let parsingFactory = OpenScreenUrlParsingServiceFactory(chainRegistryClosure: chainRegistryClosure)
        let screenOpenURLActivityValidators: [URLActivityValidator] = [ScreenOpenService.ActivityValidator()]
        let screenOpenService = ScreenOpenService(
            parsingFactory: parsingFactory,
            logger: Logger.shared,
            validators: screenOpenURLActivityValidators
        )

        let keystoreImportService = KeystoreImportService(
            validators: screenOpenURLActivityValidators,
            logger: Logger.shared
        )

        let callbackUrl = applicationConfig.purchaseRedirect
        let purchaseHandler = PurchaseCompletionHandler(
            callbackUrl: callbackUrl,
            eventCenter: eventCenter
        )

        let wcURLActivityValidators: [URLActivityValidator] = [
            WalletConnectUrlParsingService.WCActivityValidator(),
            WalletConnectUrlParsingService.OldWCActivityValidator()
        ]

        let wcHandlingService = WalletConnectUrlParsingService(validators: wcURLActivityValidators)

        let urlHandlingService = URLHandlingService(
            children: [
                screenOpenService,
                purchaseHandler,
                wcHandlingService,
                keystoreImportService
            ]
        )

        URLHandlingServiceFacade.setup(with: urlHandlingService)
    }

    private func setupPushHandlingService() {
        let handlingFactory = PushNotificationsHandlerFactory(chainRegistryClosure: chainRegistryClosure)
        let screenOpenService = PushNotificationOpenScreenFacade(
            handlingFactory: handlingFactory,
            logger: Logger.shared
        )

        PushNotificationHandlingService.shared.setup(service: screenOpenService)
    }

    private func runMigrators() {
        migrators.forEach { migrator in
            do {
                try migrator.migrate()
            } catch {
                logger?.error(error.localizedDescription)
            }
        }
    }

    private func setupTableViewsAppearance() {
        UITableView.appearance().sectionHeaderTopPadding = 0
    }

    private func setupSecurityLayer() {
        securityLayerInteractor.setup()
    }
}

extension RootInteractor: RootInteractorInputProtocol {
    func decideModuleSynchroniously() {
        do {
            if !settings.hasValue {
                try keystore.deleteKeyIfExists(for: KeystoreTag.pincode.rawValue)

                presenter?.didDecideOnboarding()
                return
            }

            let pincodeExists = try keystore.checkKey(for: KeystoreTag.pincode.rawValue)

            if pincodeExists {
                presenter?.didDecideLocalAuthentication()
            } else {
                presenter?.didDecidePincodeSetup()
            }

        } catch {
            presenter?.didDecideBroken()
        }
    }

    func setup() {
        setupSecurityLayer()
        setupTableViewsAppearance()

        setupURLHandlingService()
        setupPushHandlingService()
        runMigrators()

        settings.setup(runningCompletionIn: .main) { result in
            switch result {
            case let .success(maybeMetaAccount):
                if let metaAccount = maybeMetaAccount {
                    self.logger?.debug("Selected account: \(metaAccount.metaId)")
                } else {
                    self.logger?.debug("No selected account")
                }
            case let .failure(error):
                self.logger?.error("Selected account setup failed: \(error)")
            }
        }

        chainRegistryClosure().syncUp()
    }
}
