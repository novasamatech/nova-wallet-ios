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

        let wireframe = SettingsWireframeSpy()

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

    func testPrivacyRowFollowsTheValueTheInteractorProvides() {
        let hidden = provideAnalyticsValue(consent: makeUnattestableConsent(optedIn: false))
        let shown = provideAnalyticsValue(consent: makeUnattestableConsent(optedIn: true))

        XCTAssertNil(hidden)
        XCTAssertEqual(preferenceRows(isAnalyticsOn: hidden).map(\.row), [
            .notifications, .currency, .language, .appearance
        ])

        XCTAssertEqual(shown, true)
        XCTAssertEqual(preferenceRows(isAnalyticsOn: shown).last?.row, .privacy)
    }

    func testPrivacyRowUsesNavigationAccessoryRegardlessOfConsent() throws {
        for enabled in [false, true] {
            let consent = makeConsent()
            consent.setEnabled(enabled)
            let value = provideAnalyticsValue(consent: consent)
            let row = try XCTUnwrap(preferenceRows(isAnalyticsOn: value).last)

            XCTAssertEqual(value, enabled)
            XCTAssertEqual(row.row, .privacy)
            guard case .none = row.accessory else {
                XCTFail("Privacy must use the navigation accessory")
                continue
            }
        }
    }

    func testSelectingPrivacyDoesNotChangeAnalyticsConsent() throws {
        for enabled in [false, true] {
            let settings = InMemorySettingsManager()
            let consent = makeConsent(settings: settings)
            consent.setEnabled(enabled)
            let interactor = makeAnalyticsInteractor(consent: consent)
            let wireframe = SettingsWireframeSpy()
            let presenter = SettingsPresenter(
                viewModelFactory: SettingsViewModelFactory(
                    iconGenerator: NovaIconGenerator(),
                    quantityFormatter: NumberFormatter.quantity.localizableResource()
                ),
                config: ApplicationConfig.shared,
                interactor: interactor,
                wireframe: wireframe,
                localizationManager: LocalizationManager.shared
            )
            let row = try XCTUnwrap(preferenceRows(isAnalyticsOn: enabled).last)

            presenter.actionRow(row.row)

            XCTAssertEqual(consent.isEnabled, enabled)
            XCTAssertEqual(settings.bool(for: "analyticsEnabled"), enabled)
            XCTAssertEqual(wireframe.privacyPresentationCount, 1)
        }
    }
}

private extension SettingsTests {
    func makeConsent(settings: SettingsManagerProtocol = InMemorySettingsManager()) -> AnalyticsConsentManager {
        AnalyticsConsentManager(
            settingsManager: settings,
            availabilityProvider: AnalyticsAvailabilityProvider(attestationMode: .appAttest)
        )
    }

    func makeUnattestableConsent(optedIn: Bool, settings: SettingsManagerProtocol = InMemorySettingsManager()) -> AnalyticsConsentManager {
        makeConsent(settings: settings).setEnabled(optedIn)

        return AnalyticsConsentManager(
            settingsManager: settings,
            availabilityProvider: AnalyticsAvailabilityProvider(attestationMode: .unavailable)
        )
    }

    func provideAnalyticsValue(consent: AnalyticsConsentManagerProtocol) -> Bool? {
        let interactor = makeAnalyticsInteractor(consent: consent)
        let output = AnalyticsSettingsOutputSpy()
        interactor.presenter = output
        interactor.setup()
        return output.received.first ?? nil
    }

    func preferenceRows(isAnalyticsOn: Bool?) -> [SettingsCellViewModel] {
        let factory = SettingsViewModelFactory(iconGenerator: NovaIconGenerator(), quantityFormatter: NumberFormatter.quantity.localizableResource())
        let parameters = SettingsParameters(walletConnectSessionsCount: nil, isBiometricAuthOn: nil, isPinConfirmationOn: false, isNotificationsOn: false, isHideBalancesOn: false, isAnalyticsOn: isAnalyticsOn)
        let sections = factory.createSectionViewModels(language: nil, currency: nil, parameters: parameters, locale: Locale(identifier: "en"))
        return sections.first { $0.0 == .preferences }?.1 ?? []
    }

    func makeAnalyticsInteractor(consent: AnalyticsConsentManagerProtocol) -> SettingsInteractor {
        let eventCenter = MockEventCenterProtocol()
        stub(eventCenter) { stub in when(stub.add(observer: any(), dispatchIn: any())).thenDoNothing() }

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

        let pushNotificationsFacade = MockPushNotificationsServiceFacadeProtocol()
        stub(pushNotificationsFacade) { stub in
            when(stub.subscribeStatus(any(), closure: any())).then { _, closure in closure(.unknown, .active) }
        }

        let storageFacade = UserDataStorageTestFacade()
        let walletNotificationService = WalletNotificationService(
            proxyListLocalSubscriptionFactory: ProxyListLocalSubscriptionFactory(chainRegistry: ChainRegistryProtocolStub(), streamableProviderFactory: SubstrateDataProviderFactory(facade: SubstrateStorageTestFacade(), operationManager: OperationManagerFacade.sharedManager), storageFacade: storageFacade, operationManager: OperationManagerFacade.sharedManager, logger: Logger.shared),
            multisigListLocalSubscriptionFactory: MultisigListLocalSubscriptionFactory(storageFacade: storageFacade, operationManager: OperationManagerFacade.sharedManager, logger: Logger.shared),
            logger: Logger.shared
        )

        return SettingsInteractor(
            selectedWalletSettings: SelectedWalletSettings(storageFacade: storageFacade, operationQueue: OperationQueue()),
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

private final class SettingsWireframeSpy: MockSettingsWireframeProtocol, AnalyticsPrivacyPresentable, @unchecked Sendable {
    var privacyPresentationCount = 0

    func showPrivacy(from _: ControllerBackedProtocol?) {
        privacyPresentationCount += 1
    }
}

private final class AnalyticsSettingsOutputSpy: SettingsInteractorOutputProtocol {
    var received: [Bool?] = []

    func didReceive(analyticsEnabled: Bool?) {
        received.append(analyticsEnabled)
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
