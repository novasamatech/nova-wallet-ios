import XCTest
@testable import novawallet
import SubstrateSdk
import Keystore_iOS
import Foundation_iOS
import Cuckoo
import NovaAnalytics

final class SettingsTests: XCTestCase {
    func testSettingsSuccessfullyLoaded() throws {
        // given

        let storageFacade = UserDataStorageTestFacade()

        let walletSettings = SelectedWalletSettings(
            storageFacade: storageFacade,
            operationQueue: OperationQueue()
        )

        let selectedAccount = AccountGenerator.generateMetaAccount()

        walletSettings.save(value: selectedAccount)

        let view = MockSettingsViewProtocol()

        let accountViewModelExpectation = XCTestExpectation()
        let sectionsExpectation = XCTestExpectation()

        stub(view) { stub in
            when(stub.isSetup.get).thenReturn(false, true)

            when(stub.didLoad(userViewModel: any())).then { _ in
                accountViewModelExpectation.fulfill()
            }

            when(stub.reload(sections: any())).then { _ in
                sectionsExpectation.fulfill()
            }
        }

        let biometryAuthMock = MockBiometryAuth()

        stub(biometryAuthMock) { stub in
            when(stub.availableBiometryType.get).thenReturn(.none)
            when(stub.supportedBiometryType.get).thenReturn(.none)
        }

        let wireframe = MockSettingsWireframeProtocol()

        let eventCenter = MockEventCenterProtocol()
        let streamableProviderFactory = SubstrateDataProviderFactory(
            facade: SubstrateStorageTestFacade(),
            operationManager: OperationManagerFacade.sharedManager
        )

        let walletConnect = MockWalletConnectDelegateInputProtocol()
        let proxyListLocalSubscriptionFactory = ProxyListLocalSubscriptionFactory(
            chainRegistry: ChainRegistryProtocolStub(),
            streamableProviderFactory: streamableProviderFactory,
            storageFacade: storageFacade,
            operationManager: OperationManagerFacade.sharedManager,
            logger: Logger.shared
        )
        let multisigListLocalSubscriptionFactory = MultisigListLocalSubscriptionFactory(
            storageFacade: storageFacade,
            operationManager: OperationManagerFacade.sharedManager,
            logger: Logger.shared
        )
        let walletNotificationService = WalletNotificationService(
            proxyListLocalSubscriptionFactory: proxyListLocalSubscriptionFactory,
            multisigListLocalSubscriptionFactory: multisigListLocalSubscriptionFactory,
            logger: Logger.shared
        )

        stub(walletConnect) { stub in
            when(stub.add(delegate: any())).thenDoNothing()
            when(stub.connect(uri: any(), completion: any())).thenDoNothing()
            when(stub.remove(delegate: any())).thenDoNothing()
            when(stub.getSessionsCount()).thenReturn(0)
            when(stub.fetchSessions(any())).then { closure in
                closure(.success([]))
            }
            when(stub.disconnect(from: any(), completion: any())).then { _, completion in
                completion(nil)
            }
        }

        let operationQueue = OperationManagerFacade.sharedDefaultQueue

        let pushNotificationsFacade = MockPushNotificationsServiceFacadeProtocol()
        stub(pushNotificationsFacade) { stub in
            when(stub.subscribeStatus(any(), closure: any())).then { _, closure in
                closure(.unknown, .active)
            }
        }

        let interactor = SettingsInteractor(
            selectedWalletSettings: walletSettings,
            eventCenter: eventCenter,
            walletConnect: walletConnect,
            currencyManager: CurrencyManagerStub(),
            settingsManager: InMemorySettingsManager(),
            biometryAuth: biometryAuthMock,
            walletNotificationService: walletNotificationService,
            pushNotificationsFacade: pushNotificationsFacade,
            analyticsConsent: makeConsent(),
            privacyStateManager: PrivacyStateManager.shared,
            operationQueue: operationQueue
        )

        let viewModelFactory = SettingsViewModelFactory(
            iconGenerator: NovaIconGenerator(),
            quantityFormatter: NumberFormatter.quantity.localizableResource()
        )

        let presenter = SettingsPresenter(
            viewModelFactory: viewModelFactory,
            config: ApplicationConfig.shared,
            interactor: interactor,
            wireframe: wireframe,
            localizationManager: LocalizationManager.shared,
            logger: nil
        )

        stub(eventCenter) { stub in
            when(stub.add(observer: any(), dispatchIn: any())).thenDoNothing()
        }

        presenter.view = view
        interactor.presenter = presenter

        // when

        presenter.setup()

        // then

        wait(for: [accountViewModelExpectation, sectionsExpectation], timeout: Constants.defaultExpectationDuration)
    }

    func testAnalyticsRowIsHiddenWhenUnavailable() {
        let rows = preferenceRows(isAnalyticsOn: nil)

        XCTAssertFalse(rows.contains(.analytics))
    }

    func testAnalyticsRowAppearsAfterAppearanceWhenAvailable() {
        let rows = preferenceRows(isAnalyticsOn: false)

        XCTAssertEqual(rows.last, .analytics)
        XCTAssertEqual(rows.dropLast().last, .appearance)
    }

    func testTogglingAnalyticsRoundTripsThroughTheConsentManager() {
        let settings = InMemorySettingsManager()
        let consent = makeConsent(settings: settings)

        makeAnalyticsInteractor(consent: consent).toggleAnalytics()

        XCTAssertTrue(consent.isEnabled)
        // The accessor is internal to NovaAnalytics, so this reads the raw key the
        // package writes under.
        XCTAssertEqual(settings.bool(for: "analyticsEnabled"), true)
    }

    func testTogglingDoesNotMarkThePromptSeen() {
        let consent = makeConsent()

        makeAnalyticsInteractor(consent: consent).toggleAnalytics()

        XCTAssertFalse(consent.isPromptSeen)
    }

    func testTogglingTwiceReturnsToDisabled() {
        let consent = makeConsent()
        let interactor = makeAnalyticsInteractor(consent: consent)

        interactor.toggleAnalytics()
        interactor.toggleAnalytics()

        XCTAssertFalse(consent.isEnabled)
    }

    func testConsentChangesFromElsewhereReachTheView() {
        let consent = makeConsent()
        let interactor = makeAnalyticsInteractor(consent: consent)
        let output = AnalyticsSettingsOutputSpy()
        interactor.presenter = output

        interactor.setup()

        // The interactor observes with `queue: .main`, so the re-provide lands after this
        // test's own main-thread turn; asserting synchronously would always see only setup().
        let delivered = XCTestExpectation(description: "consent change re-provided")
        output.onReceive = { value in
            if value == true { delivered.fulfill() }
        }

        consent.setEnabled(true)

        wait(for: [delivered], timeout: 1.0)
    }

    func testUnavailableSubsystemReportsNilRatherThanFalse() {
        let consent = AnalyticsConsentManager(
            settingsManager: InMemorySettingsManager(),
            availabilityProvider: AnalyticsAvailabilityProvider(attestationMode: .unavailable)
        )
        let interactor = makeAnalyticsInteractor(consent: consent)
        let output = AnalyticsSettingsOutputSpy()
        interactor.presenter = output

        interactor.setup()

        XCTAssertEqual(output.received.first, .some(nil))
    }
}

// MARK: - Analytics helpers

private extension SettingsTests {
    func makeConsent(
        settings: SettingsManagerProtocol = InMemorySettingsManager()
    ) -> AnalyticsConsentManager {
        AnalyticsConsentManager(
            settingsManager: settings,
            availabilityProvider: AnalyticsAvailabilityProvider(attestationMode: .appAttest)
        )
    }

    func preferenceRows(isAnalyticsOn: Bool?) -> [SettingsRow] {
        let factory = SettingsViewModelFactory(
            iconGenerator: NovaIconGenerator(),
            quantityFormatter: NumberFormatter.quantity.localizableResource()
        )

        let sections = factory.createSectionViewModels(
            language: nil,
            currency: nil,
            parameters: SettingsParameters(
                walletConnectSessionsCount: nil,
                isBiometricAuthOn: nil,
                isPinConfirmationOn: false,
                isNotificationsOn: false,
                isHideBalancesOn: false,
                isAnalyticsOn: isAnalyticsOn
            ),
            locale: Locale(identifier: "en")
        )

        return sections.first { $0.0 == .preferences }?.1.map(\.row) ?? []
    }

    /// Only the analytics collaborator is real; everything else is the cheapest stand-in that
    /// lets `setup()` and `toggleAnalytics()` run, since neither touches them.
    func makeAnalyticsInteractor(consent: AnalyticsConsentManagerProtocol) -> SettingsInteractor {
        let eventCenter = MockEventCenterProtocol()
        stub(eventCenter) { stub in
            when(stub.add(observer: any(), dispatchIn: any())).thenDoNothing()
        }

        let walletConnect = MockWalletConnectDelegateInputProtocol()
        stub(walletConnect) { stub in
            when(stub.add(delegate: any())).thenDoNothing()
            when(stub.getSessionsCount()).thenReturn(0)
        }

        let biometryAuth = MockBiometryAuthProtocol()
        stub(biometryAuth) { stub in
            when(stub.availableBiometryType.get).thenReturn(.none)
            when(stub.supportedBiometryType.get).thenReturn(.none)
        }

        let storageFacade = UserDataStorageTestFacade()
        let walletNotificationService = WalletNotificationService(
            proxyListLocalSubscriptionFactory: ProxyListLocalSubscriptionFactory(
                chainRegistry: ChainRegistryProtocolStub(),
                streamableProviderFactory: SubstrateDataProviderFactory(
                    facade: SubstrateStorageTestFacade(),
                    operationManager: OperationManagerFacade.sharedManager
                ),
                storageFacade: storageFacade,
                operationManager: OperationManagerFacade.sharedManager,
                logger: Logger.shared
            ),
            multisigListLocalSubscriptionFactory: MultisigListLocalSubscriptionFactory(
                storageFacade: storageFacade,
                operationManager: OperationManagerFacade.sharedManager,
                logger: Logger.shared
            ),
            logger: Logger.shared
        )

        let pushNotificationsFacade = MockPushNotificationsServiceFacadeProtocol()
        stub(pushNotificationsFacade) { stub in
            when(stub.subscribeStatus(any(), closure: any())).then { _, closure in
                closure(.unknown, .active)
            }
        }

        return SettingsInteractor(
            selectedWalletSettings: SelectedWalletSettings(
                storageFacade: storageFacade,
                operationQueue: OperationQueue()
            ),
            eventCenter: eventCenter,
            walletConnect: walletConnect,
            currencyManager: CurrencyManagerStub(),
            settingsManager: InMemorySettingsManager(),
            biometryAuth: biometryAuth,
            walletNotificationService: walletNotificationService,
            pushNotificationsFacade: pushNotificationsFacade,
            analyticsConsent: consent,
            privacyStateManager: PrivacyStateManager.shared,
            operationQueue: OperationQueue()
        )
    }
}

private final class AnalyticsSettingsOutputSpy: SettingsInteractorOutputProtocol {
    var received: [Bool?] = []
    var onReceive: ((Bool?) -> Void)?

    func didReceive(analyticsEnabled: Bool?) {
        received.append(analyticsEnabled)
        onReceive?(analyticsEnabled)
    }

    func didReceive(wallet _: MetaAccountModel) {}
    func didReceiveUserDataProvider(error _: Error) {}
    func didReceive(currencyCode _: String) {}
    func didReceiveWalletConnect(sessionsCount _: Int) {}
    func didReceive(biometrySettings _: BiometrySettings) {}
    func didReceive(pinConfirmationEnabled _: Bool) {}
    func didReceive(error _: SettingsError) {}
    func didReceiveWalletsState(hasUpdates _: Bool) {}
    func didReceive(pushNotificationsStatus _: PushNotificationsStatus) {}
    func didReceive(hideBalancesOnLaunch _: Bool) {}
}
