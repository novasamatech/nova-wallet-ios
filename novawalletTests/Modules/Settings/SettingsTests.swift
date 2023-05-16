import XCTest
@testable import novawallet
import SubstrateSdk
import SoraKeystore
import SoraFoundation
import Cuckoo

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
            when(stub).isSetup.get.thenReturn(false, true)

            when(stub).didLoad(userViewModel: any()).then { _ in
                accountViewModelExpectation.fulfill()
            }

            when(stub).reload(sections: any()).then { _ in
                sectionsExpectation.fulfill()
            }
        }
        
        let biometryAuthMock = MockBiometryAuth()
        
        stub(biometryAuthMock) { stub in
            when(stub).availableBiometryType.get.thenReturn(.none)
            when(stub).supportedBiometryType.get.thenReturn(.none)
        }

        let wireframe = MockSettingsWireframeProtocol()

        let eventCenter = MockEventCenterProtocol()

        let walletConnect = MockWalletConnectDelegateInputProtocol()

        stub(walletConnect) { stub in
            when(stub).add(delegate: any()).thenDoNothing()
            when(stub).connect(uri: any(), completion: any()).thenDoNothing()
            when(stub).remove(delegate: any()).thenDoNothing()
            when(stub).getSessionsCount().thenReturn(0)
            when(stub).fetchSessions(any()).then { closure in
                closure(.success([]))
            }
            when(stub).disconnect(from: any(), completion: any()).then { session, completion in
                completion(nil)
            }
        }

        let interactor = SettingsInteractor(
            selectedWalletSettings: walletSettings,
            eventCenter: eventCenter,
            walletConnect: walletConnect,
            currencyManager: CurrencyManagerStub(),
            settingsManager: InMemorySettingsManager(),
            biometryAuth: biometryAuthMock
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
            when(stub).add(observer: any(), dispatchIn: any()).thenDoNothing()
        }

        presenter.view = view
        interactor.presenter = presenter

        // when

        presenter.setup()

        // then

        wait(for: [accountViewModelExpectation, sectionsExpectation], timeout: Constants.defaultExpectationDuration)
    }
}
