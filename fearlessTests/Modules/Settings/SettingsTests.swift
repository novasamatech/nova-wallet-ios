import XCTest
@testable import fearless
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

        let wireframe = MockSettingsWireframeProtocol()

        let eventCenter = MockEventCenterProtocol()
        let interactor = SettingsInteractor(
            selectedWalletSettings: walletSettings,
            eventCenter: eventCenter
        )

        let viewModelFactory = SettingsViewModelFactory(iconGenerator: NovaIconGenerator())

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
